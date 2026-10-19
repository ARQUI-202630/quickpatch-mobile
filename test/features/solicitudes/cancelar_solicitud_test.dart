import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/core/catalogo/categoria.dart';
import 'package:quickpatch_mobile/core/catalogo/repositorio_catalogo.dart';
import 'package:quickpatch_mobile/core/realtime/canal_tiempo_real.dart';
import 'package:quickpatch_mobile/features/solicitudes/data/repositorio_solicitudes.dart';
import 'package:quickpatch_mobile/features/solicitudes/domain/modelos.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/paginas/detalle_solicitud_page.dart';

import '../../helpers/fakes.dart';

/// Cancelación desde el detalle del cliente (RF-36, SCRUM-477; contrato
/// service-request 1.5.0).
Solicitud _solicitud(
  EstadoSolicitud estado, {
  DateTime? canceladaEn,
  String? motivo,
}) => Solicitud(
  id: 's-1',
  estado: estado,
  categoriaId: 'c-1',
  descripcion: 'Fuga de agua debajo del lavaplatos',
  ubicacion: const Ubicacion(4.6533, -74.0836),
  direccion: 'Calle 45 # 13-20',
  creadaEn: DateTime.utc(2026, 10, 7, 15),
  canceladaEn: canceladaEn,
  motivoCancelacion: motivo,
);

void main() {
  late AdaptadorFalso adaptador;
  late Solicitud actual;
  late int consultas;

  setUp(() {
    actual = _solicitud(EstadoSolicitud.buscandoTecnico);
    consultas = 0;
    adaptador = AdaptadorFalso((o) {
      // El backend ya la canceló: la siguiente consulta del detalle lo refleja.
      actual = _solicitud(
        EstadoSolicitud.cancelado,
        canceladaEn: DateTime.utc(2026, 10, 19, 16, 20),
        motivo: 'Ya no necesito el servicio.',
      );
      return respuestaJson({
        'id': 's-1',
        'status': 'cancelado',
        'cancelledAt': '2026-10-19T16:20:00Z',
        'cancelledByType': 'cliente',
      }, 200);
    });
  });

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final conector = ConectorWsFalso();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          solicitudProvider.overrideWith((ref, id) async {
            consultas++;
            return actual;
          }),
          repositorioSolicitudesProvider.overrideWithValue(
            RepositorioSolicitudes(
              Dio(BaseOptions(baseUrl: 'https://qa.quickpatch.internal/api'))
                ..httpClientAdapter = adaptador,
            ),
          ),
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
          theme: AppTheme.claro(),
          home: const DetalleSolicitudPage(id: 's-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> escribirYConfirmar(WidgetTester tester, String motivo) async {
    await tester.tap(find.byKey(const Key('boton-cancelar-solicitud')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo-motivo-cancelacion')),
      motivo,
    );
    await tester.tap(find.byKey(const Key('confirmar-cancelacion')));
    await tester.pumpAndSettle();
  }

  for (final estado in EstadoSolicitud.values) {
    testWidgets('en ${estado.valor} el botón de cancelar '
        '${estado.cancelable ? 'aparece' : 'no aparece'}', (tester) async {
      actual = _solicitud(estado);
      await abrir(tester);

      expect(
        find.byKey(const Key('boton-cancelar-solicitud')),
        estado.cancelable ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets('cancela con el motivo sin espacios, avisa y muestra el motivo', (
    tester,
  ) async {
    await abrir(tester);
    final antes = consultas;

    await escribirYConfirmar(tester, '  Ya no necesito el servicio.  ');

    final peticion = adaptador.ultima!;
    expect(peticion.method, 'POST');
    expect(peticion.path, '/v1/service-requests/s-1/cancel');
    expect(peticion.data, {'reason': 'Ya no necesito el servicio.'});
    expect(find.text('Cancelaste la solicitud.'), findsOneWidget);
    expect(consultas, greaterThan(antes));
    expect(find.text('Cancelada'), findsWidgets);
    expect(find.byKey(const Key('tarjeta-cancelacion')), findsOneWidget);
    expect(find.text('Ya no necesito el servicio.'), findsOneWidget);
    expect(find.byKey(const Key('boton-cancelar-solicitud')), findsNothing);
    expect(find.byKey(const Key('linea-de-tiempo')), findsNothing);
  });

  testWidgets('un motivo de menos de 5 caracteres no llama al backend', (
    tester,
  ) async {
    await abrir(tester);

    await escribirYConfirmar(tester, ' no ');

    expect(adaptador.ultima, isNull);
    expect(find.textContaining('mínimo 5 caracteres'), findsOneWidget);
    expect(find.byKey(const Key('confirmar-cancelacion')), findsOneWidget);
  });

  testWidgets('volver cierra el diálogo sin cancelar', (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(const Key('boton-cancelar-solicitud')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    expect(adaptador.ultima, isNull);
    expect(find.byKey(const Key('campo-motivo-cancelacion')), findsNothing);
    expect(find.byKey(const Key('boton-cancelar-solicitud')), findsOneWidget);
  });

  testWidgets('un 409 explica que el servicio ya inició y recarga el detalle', (
    tester,
  ) async {
    adaptador.responder = (o) {
      actual = _solicitud(EstadoSolicitud.enProgreso);
      return respuestaJson({
        'type': 'https://quickpatch.internal/problems/transicion-invalida',
        'title': 'La solicitud ya no se puede cancelar',
        'status': 409,
      }, 409);
    };
    await abrir(tester);

    await escribirYConfirmar(tester, 'Ya no lo necesito');

    expect(find.textContaining('El servicio ya inició'), findsOneWidget);
    expect(find.byKey(const Key('campo-motivo-cancelacion')), findsNothing);
    expect(find.text('En progreso'), findsWidgets);
    expect(find.byKey(const Key('boton-cancelar-solicitud')), findsNothing);
  });

  testWidgets('un 400 de reason muestra el mensaje en el campo', (
    tester,
  ) async {
    adaptador.responder = (o) => respuestaJson({
      'type': 'https://quickpatch.internal/problems/validacion',
      'title': 'La solicitud tiene datos inválidos',
      'status': 400,
      'errors': {
        'reason': ['El motivo debe tener entre 5 y 500 caracteres.'],
      },
    }, 400);
    await abrir(tester);

    await escribirYConfirmar(tester, 'Ya no lo necesito');

    expect(
      find.text('El motivo debe tener entre 5 y 500 caracteres.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('confirmar-cancelacion')), findsOneWidget);
  });

  test('el detalle lee la cancelación de la versión 1.5.0', () {
    final s = Solicitud.desdeJson({
      'id': 's-1',
      'status': 'cancelado',
      'categoryId': 'c-1',
      'description': 'Fuga',
      'location': {'latitude': 4.6, 'longitude': -74.0},
      'addressText': 'Calle 45',
      'createdAt': '2026-10-07T15:00:00Z',
      'cancelledAt': '2026-10-19T16:20:00Z',
      'cancellationReason': 'Ya no necesito el servicio.',
    });
    expect(s.canceladaEn, DateTime.utc(2026, 10, 19, 16, 20));
    expect(s.motivoCancelacion, 'Ya no necesito el servicio.');
  });

  test('solo se cancela antes de en_progreso (RN-SR7)', () {
    expect(EstadoSolicitud.values.where((e) => e.cancelable), [
      EstadoSolicitud.buscandoTecnico,
      EstadoSolicitud.enEspera,
      EstadoSolicitud.asignado,
      EstadoSolicitud.cotizado,
      EstadoSolicitud.cotizacionAceptada,
    ]);
  });
}
