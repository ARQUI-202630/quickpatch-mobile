import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/core/catalogo/categoria.dart';
import 'package:quickpatch_mobile/core/catalogo/repositorio_catalogo.dart';
import 'package:quickpatch_mobile/core/realtime/canal_tiempo_real.dart';
import 'package:quickpatch_mobile/core/utils/reloj.dart';
import 'package:quickpatch_mobile/features/solicitudes/data/repositorio_solicitudes.dart';
import 'package:quickpatch_mobile/features/solicitudes/domain/modelos.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/paginas/detalle_solicitud_page.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/widgets/cotizacion_cliente.dart';

import '../../helpers/cotizaciones.dart';
import '../../helpers/fakes.dart';

/// Aceptar o rechazar la cotización desde el detalle del cliente (RF-35,
/// SCRUM-489; contrato service-request 1.6.0).
Solicitud _solicitud(EstadoSolicitud estado) => Solicitud(
  id: 's-1',
  estado: estado,
  categoriaId: 'c-1',
  descripcion: 'Fuga de agua debajo del lavaplatos',
  ubicacion: const Ubicacion(4.6533, -74.0836),
  direccion: 'Calle 45 # 13-20',
  creadaEn: DateTime.utc(2026, 10, 20, 14),
);

Map<String, dynamic> _decision(String cotizacion, String solicitud, int n) => {
  'quoteId': 'q-1',
  'quoteStatus': cotizacion,
  'serviceRequestStatus': solicitud,
  'remainingQuotes': n,
};

void main() {
  late AdaptadorFalso adaptador;
  late Solicitud actual;
  late List<Map<String, dynamic>> cotizaciones;
  late int consultas;
  late DateTime ahora;

  setUp(() {
    actual = _solicitud(EstadoSolicitud.cotizado);
    cotizaciones = [cotizacionJson()];
    consultas = 0;
    ahora = DateTime.utc(2026, 10, 20, 18);
    adaptador = AdaptadorFalso((o) {
      // El backend ya la aceptó: la siguiente consulta lo refleja.
      actual = _solicitud(EstadoSolicitud.cotizacionAceptada);
      cotizaciones = [cotizacionJson(estado: 'aceptada')];
      return respuestaJson(
        _decision('aceptada', 'cotizacion_aceptada', 2),
        200,
      );
    });
  });

  Future<void> abrir(
    WidgetTester tester, {
    ThemeData? tema,
    double escalaTexto = 1,
  }) async {
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = escalaTexto;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final conector = ConectorWsFalso();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          solicitudProvider.overrideWith((ref, id) async {
            consultas++;
            return actual;
          }),
          cotizacionesProvider.overrideWith(
            (ref, id) async => cotizaciones.map(Cotizacion.desdeJson).toList(),
          ),
          repositorioSolicitudesProvider.overrideWithValue(
            RepositorioSolicitudes(
              Dio(BaseOptions(baseUrl: 'https://qa.quickpatch.internal/api'))
                ..httpClientAdapter = adaptador,
            ),
          ),
          relojProvider.overrideWithValue(() => ahora),
          categoriasProvider.overrideWith(
            (ref) async => const [Categoria(id: 'c-1', nombre: 'Plomería')],
          ),
          canalTiempoRealProvider.overrideWith((ref) {
            final canal = CanalTiempoReal(
              url: Uri.parse('ws://localhost/api/v1/realtime'),
              obtenerToken: () => 'token-acceso',
              conectar: conector.call,
            );
            ref.onDispose(canal.cerrar);
            canal.iniciar();
            return canal;
          }),
        ],
        child: MaterialApp(
          theme: tema ?? AppTheme.claro(),
          home: const DetalleSolicitudPage(id: 's-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder clave(String k) => find.byKey(Key(k));

  Future<void> tocar(WidgetTester tester, String k) async {
    await tester.ensureVisible(clave(k));
    await tester.tap(clave(k));
    await tester.pumpAndSettle();
  }

  Future<void> rechazar(WidgetTester tester, String motivo) async {
    await tocar(tester, 'boton-rechazar-cotizacion');
    await tester.enterText(clave('campo-motivo-rechazo'), motivo);
    await tocar(tester, 'confirmar-rechazo');
  }

  testWidgets('en cotizado muestra el desglose, el total y las acciones', (
    tester,
  ) async {
    await abrir(tester);

    expect(clave('cotizacion-pendiente'), findsOneWidget);
    expect(find.text(r'$ 120.000'), findsOneWidget);
    expect(find.text(r'$ 65.000'), findsOneWidget);
    expect(tester.widget<Text>(clave('total-cotizacion-1')).data, r'$ 185.000');
    expect(find.textContaining('Vence el'), findsOneWidget);
    expect(clave('boton-aceptar-cotizacion'), findsOneWidget);
    expect(clave('boton-rechazar-cotizacion'), findsOneWidget);
    expect(clave('aviso-ultima-cotizacion'), findsNothing);
  });

  for (final estado in EstadoSolicitud.values) {
    final aplica =
        estado == EstadoSolicitud.cotizado ||
        estado == EstadoSolicitud.cotizacionAceptada;
    testWidgets('en ${estado.valor} la cotización '
        '${aplica ? 'aparece' : 'no aparece'}', (tester) async {
      actual = _solicitud(estado);
      cotizaciones = [
        cotizacionJson(
          estado: estado == EstadoSolicitud.cotizacionAceptada
              ? 'aceptada'
              : 'pendiente',
        ),
      ];
      await abrir(tester);

      expect(
        find.byType(CotizacionCliente),
        aplica ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets('acepta tras confirmar el total y recarga el estado', (
    tester,
  ) async {
    await abrir(tester);
    final antes = consultas;

    await tocar(tester, 'boton-aceptar-cotizacion');
    expect(find.textContaining(r'Pagarás $ 185.000'), findsOneWidget);
    await tocar(tester, 'confirmar-aceptar-cotizacion');

    final peticion = adaptador.ultima!;
    expect(peticion.method, 'POST');
    expect(peticion.path, '/v1/service-requests/s-1/quotes/q-1/accept');
    expect(peticion.data, isNull);
    expect(
      find.textContaining('El técnico ya puede iniciar el servicio'),
      findsOneWidget,
    );
    expect(consultas, greaterThan(antes));
    expect(clave('cotizacion-aceptada'), findsOneWidget);
    expect(clave('boton-aceptar-cotizacion'), findsNothing);
  });

  testWidgets('volver en la confirmación no acepta', (tester) async {
    await abrir(tester);

    await tocar(tester, 'boton-aceptar-cotizacion');
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    expect(adaptador.ultima, isNull);
    expect(clave('cotizacion-pendiente'), findsOneWidget);
  });

  testWidgets('rechaza sin motivo sin enviar cuerpo', (tester) async {
    adaptador.responder = (o) {
      actual = _solicitud(EstadoSolicitud.asignado);
      cotizaciones = [cotizacionJson(estado: 'rechazada')];
      return respuestaJson(_decision('rechazada', 'asignado', 2), 200);
    };
    await abrir(tester);

    await rechazar(tester, '   ');

    final peticion = adaptador.ultima!;
    expect(peticion.path, '/v1/service-requests/s-1/quotes/q-1/reject');
    expect(peticion.data, isNull);
    expect(
      find.textContaining('El técnico puede enviarte otra'),
      findsOneWidget,
    );
    expect(find.text('Técnico asignado'), findsWidgets);
    expect(find.byType(CotizacionCliente), findsNothing);
  });

  testWidgets('rechaza con el motivo sin espacios', (tester) async {
    adaptador.responder = (o) =>
        respuestaJson(_decision('rechazada', 'asignado', 2), 200);
    await abrir(tester);

    await rechazar(tester, '  El valor es muy alto.  ');

    expect(adaptador.ultima!.data, {'reason': 'El valor es muy alto.'});
  });

  testWidgets('un motivo de menos de 5 caracteres no llama al backend', (
    tester,
  ) async {
    await abrir(tester);

    await rechazar(tester, 'caro');

    expect(adaptador.ultima, isNull);
    expect(find.textContaining('al menos 5 caracteres'), findsOneWidget);
    expect(clave('confirmar-rechazo'), findsOneWidget);
  });

  testWidgets('la tercera avisa que rechazarla cancela la solicitud', (
    tester,
  ) async {
    cotizaciones = [
      cotizacionJson(estado: 'rechazada'),
      cotizacionJson(numero: 2, estado: 'rechazada'),
      cotizacionJson(numero: 3),
    ];
    adaptador.responder = (o) {
      actual = _solicitud(EstadoSolicitud.cancelado);
      return respuestaJson(_decision('rechazada', 'cancelado', 0), 200);
    };
    await abrir(tester);

    expect(clave('aviso-ultima-cotizacion'), findsOneWidget);
    await tocar(tester, 'boton-rechazar-cotizacion');
    expect(
      tester.widget<Text>(clave('explicacion-rechazo')).data,
      contains('la solicitud se cancela'),
    );
    await tester.enterText(clave('campo-motivo-rechazo'), 'Muy costosa.');
    await tocar(tester, 'confirmar-rechazo');

    expect(
      adaptador.ultima!.path,
      '/v1/service-requests/s-1/quotes/q-3/reject',
    );
    expect(
      find.text('Rechazaste la tercera cotización y la solicitud se canceló.'),
      findsOneWidget,
    );
    expect(find.text('Cancelada'), findsWidgets);
  });

  testWidgets('un 409 al aceptar explica que ya no se puede y recarga', (
    tester,
  ) async {
    adaptador.responder = (o) {
      actual = _solicitud(EstadoSolicitud.cancelado);
      cotizaciones = [cotizacionJson(estado: 'expirada')];
      return respuestaJson({
        'type': 'https://quickpatch.internal/problems/transicion-invalida',
        'title': 'La cotización no admite la operación',
        'status': 409,
      }, 409);
    };
    await abrir(tester);
    final antes = consultas;

    await tocar(tester, 'boton-aceptar-cotizacion');
    await tocar(tester, 'confirmar-aceptar-cotizacion');

    expect(find.text(avisoConflicto), findsOneWidget);
    expect(consultas, greaterThan(antes));
    expect(find.text('Cancelada'), findsWidgets);
    expect(clave('boton-aceptar-cotizacion'), findsNothing);
  });

  testWidgets('un 409 al rechazar cierra el diálogo y recarga', (tester) async {
    adaptador.responder = (o) => respuestaJson({
      'type': 'https://quickpatch.internal/problems/transicion-invalida',
      'title': 'La cotización no admite la operación',
      'status': 409,
    }, 409);
    await abrir(tester);
    final antes = consultas;

    await rechazar(tester, '');

    expect(find.text(avisoConflicto), findsOneWidget);
    expect(clave('campo-motivo-rechazo'), findsNothing);
    expect(consultas, greaterThan(antes));
  });

  testWidgets('vencida: ya no ofrece aceptar ni rechazar', (tester) async {
    ahora = DateTime.utc(2026, 10, 21, 15);
    await abrir(tester);

    expect(clave('cotizacion-vencida'), findsOneWidget);
    expect(clave('boton-aceptar-cotizacion'), findsNothing);
    expect(clave('boton-rechazar-cotizacion'), findsNothing);
  });

  testWidgets('tema oscuro y texto al 200 % sin desbordes', (tester) async {
    cotizaciones = [cotizacionJson(numero: 3)];
    await abrir(tester, tema: AppTheme.oscuro(), escalaTexto: 2);
    await tocar(tester, 'boton-rechazar-cotizacion');

    expect(tester.takeException(), isNull);
  });

  group('contrato 1.6.0', () {
    test('lee la cotización sin convertir los montos a double', () {
      final c = Cotizacion.desdeJson(
        cotizacionJson(estado: 'rechazada', motivo: 'Muy costosa.'),
      );
      expect(c.numero, 1);
      expect(c.estado, EstadoCotizacion.rechazada);
      expect(c.manoDeObra.valor, '120000.00');
      expect(c.total.formatear(), r'$ 185.000');
      expect(c.venceEn, DateTime.utc(2026, 10, 21, 15));
      expect(c.respondidaEn, DateTime.utc(2026, 10, 20, 16));
      expect(c.motivoRechazo, 'Muy costosa.');
    });

    test('solo se responde pendiente y antes del vencimiento (RN-Q8)', () {
      final c = Cotizacion.desdeJson(cotizacionJson());
      expect(c.respondibleEn(DateTime.utc(2026, 10, 21, 14, 59)), isTrue);
      expect(c.respondibleEn(DateTime.utc(2026, 10, 21, 15)), isFalse);
      expect(
        Cotizacion.desdeJson(cotizacionJson(estado: 'aceptada'))
            .respondibleEn(DateTime.utc(2026, 10, 20)),
        isFalse,
      );
    });

    test('lee la decisión', () {
      final d = DecisionCotizacion.desdeJson(
        _decision('rechazada', 'cancelado', 0),
      );
      expect(d.estadoCotizacion, EstadoCotizacion.rechazada);
      expect(d.estadoSolicitud, EstadoSolicitud.cancelado);
      expect(d.restantes, 0);
    });

    test('lista las cotizaciones de la solicitud', () async {
      final adaptador = AdaptadorFalso(
        (o) =>
            respuestaJson([cotizacionJson(), cotizacionJson(numero: 2)], 200),
      );
      final repositorio = RepositorioSolicitudes(
        Dio(BaseOptions(baseUrl: 'https://qa.quickpatch.internal/api'))
          ..httpClientAdapter = adaptador,
      );

      final lista = await repositorio.cotizaciones('s-1');

      expect(adaptador.ultima!.method, 'GET');
      expect(adaptador.ultima!.path, '/v1/service-requests/s-1/quotes');
      expect(lista.map((c) => c.numero), [1, 2]);
    });
  });
}
