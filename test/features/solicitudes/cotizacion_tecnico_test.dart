import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/features/solicitudes/data/repositorio_solicitudes.dart';
import 'package:quickpatch_mobile/features/solicitudes/domain/modelos.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/widgets/cotizacion_tecnico.dart';

import '../../helpers/cotizaciones.dart';
import '../../helpers/fakes.dart';

/// Cotización desde la app del técnico (RF-34, SCRUM-489; contrato
/// service-request 1.6.0).
Solicitud _solicitud(EstadoSolicitud estado) => Solicitud(
  id: 's-1',
  estado: estado,
  categoriaId: 'c-1',
  descripcion: 'Fuga de agua debajo del lavaplatos',
  ubicacion: const Ubicacion(4.6765, -74.0480),
  direccion: 'Calle 93 # 13-20',
  creadaEn: DateTime.utc(2026, 10, 20, 14),
);

void main() {
  late AdaptadorFalso adaptador;
  late List<Map<String, dynamic>> cotizaciones;
  late int cambios;

  setUp(() {
    cotizaciones = [];
    cambios = 0;
    adaptador = AdaptadorFalso((o) => respuestaJson(cotizacionJson(), 201));
  });

  Future<void> abrir(
    WidgetTester tester,
    EstadoSolicitud estado, {
    ThemeData? tema,
    double escalaTexto = 1,
  }) async {
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = escalaTexto;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cotizacionesProvider.overrideWith(
            (ref, id) async => cotizaciones.map(Cotizacion.desdeJson).toList(),
          ),
          repositorioSolicitudesProvider.overrideWithValue(
            RepositorioSolicitudes(
              Dio(BaseOptions(baseUrl: 'https://qa.quickpatch.internal/api'))
                ..httpClientAdapter = adaptador,
            ),
          ),
        ],
        child: MaterialApp(
          theme: tema ?? AppTheme.claro(),
          home: Scaffold(
            body: ListView(
              children: [
                CotizacionTecnico(
                  solicitud: _solicitud(estado),
                  alCambiar: () => cambios++,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder clave(String k) => find.byKey(Key(k));

  Future<void> llenar(
    WidgetTester tester, {
    String manoDeObra = '',
    String materiales = '',
    String detalle = '',
  }) async {
    await tester.enterText(clave('campo-mano-de-obra'), manoDeObra);
    await tester.enterText(clave('campo-materiales'), materiales);
    await tester.enterText(clave('campo-detalle-cotizacion'), detalle);
    await tester.pump();
  }

  /// Tras un envío exitoso el botón sigue ocupado hasta que la pantalla
  /// recarga (así no se envía dos veces): se avanza el tiempo sin esperar a
  /// que todo se detenga.
  Future<void> enviar(WidgetTester tester) async {
    await tester.ensureVisible(clave('boton-enviar-cotizacion'));
    await tester.tap(clave('boton-enviar-cotizacion'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  String total(WidgetTester tester) =>
      tester.widget<Text>(clave('total-nueva-cotizacion')).data!;

  testWidgets('en asignado muestra el formulario y el total antes de enviar', (
    tester,
  ) async {
    await abrir(tester, EstadoSolicitud.asignado);

    expect(find.text('Cotización 1 de 3'), findsOneWidget);
    expect(total(tester), r'$ 0');

    await llenar(tester, manoDeObra: '120000', materiales: '65000');
    expect(total(tester), r'$ 185.000');
    expect(
      tester.widget<Text>(clave('cotizaciones-restantes')).data,
      'Si el cliente la rechaza, puedes enviar hasta 2 más.',
    );
  });

  testWidgets('los montos solo aceptan dígitos', (tester) async {
    await abrir(tester, EstadoSolicitud.asignado);

    await llenar(tester, manoDeObra: '12.000,50', materiales: '-3abc');

    expect(find.text('1200050'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(total(tester), r'$ 1.200.053');
  });

  testWidgets('sin mano de obra no llama al backend', (tester) async {
    await abrir(tester, EstadoSolicitud.asignado);

    await llenar(tester, manoDeObra: '0', materiales: '65000');
    await enviar(tester);

    expect(adaptador.ultima, isNull);
    expect(find.textContaining('mayor que \$ 0'), findsOneWidget);
  });

  testWidgets('un total de más de 10 dígitos no se envía', (tester) async {
    await abrir(tester, EstadoSolicitud.asignado);

    await llenar(tester, manoDeObra: '9999999999', materiales: '1');
    expect(total(tester), 'Supera el máximo');
    await enviar(tester);

    expect(adaptador.ultima, isNull);
    expect(find.textContaining('El total no puede superar'), findsOneWidget);
  });

  testWidgets('envía los montos con dos decimales y recarga el estado', (
    tester,
  ) async {
    await abrir(tester, EstadoSolicitud.asignado);

    await llenar(
      tester,
      manoDeObra: '120000',
      detalle: '  Cambio de sifón y empaques.  ',
    );
    await enviar(tester);

    final peticion = adaptador.ultima!;
    expect(peticion.method, 'POST');
    expect(peticion.path, '/v1/service-requests/s-1/quotes');
    expect(peticion.data, {
      'laborAmount': '120000.00',
      'materialsAmount': '0.00',
      'detail': 'Cambio de sifón y empaques.',
    });
    expect(find.textContaining('Enviaste la cotización'), findsOneWidget);
    expect(cambios, 1);
    final boton = tester.widget<FilledButton>(clave('boton-enviar-cotizacion'));
    expect(boton.onPressed, isNull);
  });

  testWidgets('sin detalle no envía el campo', (tester) async {
    await abrir(tester, EstadoSolicitud.asignado);

    await llenar(tester, manoDeObra: '50000', materiales: '10000');
    await enviar(tester);

    expect(adaptador.ultima!.data, {
      'laborAmount': '50000.00',
      'materialsAmount': '10000.00',
    });
  });

  for (final (problema, mensaje) in [
    ('limite-de-cotizaciones', 'Ya enviaste las 3 cotizaciones'),
    ('transicion-invalida', 'La solicitud ya no admite una cotización'),
  ]) {
    testWidgets('un 409 $problema avisa y recarga el estado', (tester) async {
      adaptador.responder = (o) => respuestaJson({
        'type': 'https://quickpatch.internal/problems/$problema',
        'title': 'Conflicto',
        'status': 409,
      }, 409);
      await abrir(tester, EstadoSolicitud.asignado);

      await llenar(tester, manoDeObra: '120000');
      await enviar(tester);

      expect(find.textContaining(mensaje), findsOneWidget);
      expect(cambios, 1);
    });
  }

  testWidgets('un 400 muestra el error en su campo', (tester) async {
    adaptador.responder = (o) => respuestaJson({
      'type': 'https://quickpatch.internal/problems/validacion',
      'title': 'La cotización tiene datos inválidos',
      'status': 400,
      'errors': {
        'laborAmount': ['La mano de obra debe ser mayor que 0.'],
      },
    }, 400);
    await abrir(tester, EstadoSolicitud.asignado);

    await llenar(tester, manoDeObra: '120000');
    await enviar(tester);

    expect(find.text('La mano de obra debe ser mayor que 0.'), findsOneWidget);
    expect(cambios, 0);
    expect(clave('boton-enviar-cotizacion'), findsOneWidget);
  });

  testWidgets('en cotizado muestra la cotización que espera respuesta', (
    tester,
  ) async {
    cotizaciones = [cotizacionJson()];
    await abrir(tester, EstadoSolicitud.cotizado);

    expect(clave('formulario-cotizacion'), findsNothing);
    expect(find.text('Esperando la respuesta del cliente'), findsOneWidget);
    expect(tester.widget<Text>(clave('total-cotizacion-1')).data, r'$ 185.000');
    expect(find.text('Cambio de sifón y empaques.'), findsOneWidget);
    expect(clave('vencimiento-cotizacion-1'), findsOneWidget);
  });

  testWidgets('en cotizacion_aceptada muestra la aceptada', (tester) async {
    cotizaciones = [
      cotizacionJson(estado: 'rechazada'),
      cotizacionJson(numero: 2, estado: 'aceptada'),
    ];
    await abrir(tester, EstadoSolicitud.cotizacionAceptada);

    expect(find.text('El cliente aceptó tu cotización'), findsOneWidget);
    expect(clave('cotizacion-anterior-1'), findsOneWidget);
  });

  testWidgets('tras dos rechazos, la tercera avisa que es la última', (
    tester,
  ) async {
    cotizaciones = [
      cotizacionJson(estado: 'rechazada', motivo: 'Muy costosa.'),
      cotizacionJson(numero: 2, estado: 'rechazada'),
    ];
    await abrir(tester, EstadoSolicitud.asignado);

    expect(find.text('Cotización 3 de 3'), findsOneWidget);
    expect(find.textContaining('Es tu última cotización'), findsOneWidget);
    expect(find.text('Cotización 1: rechazada'), findsOneWidget);
    expect(find.text('Motivo: Muy costosa.'), findsOneWidget);
  });

  testWidgets('con 3 cotizaciones ya no muestra el formulario', (tester) async {
    cotizaciones = [
      for (var n = 1; n <= 3; n++)
        cotizacionJson(numero: n, estado: 'expirada'),
    ];
    await abrir(tester, EstadoSolicitud.asignado);

    expect(clave('formulario-cotizacion'), findsNothing);
    expect(clave('sin-cotizaciones-restantes'), findsOneWidget);
  });

  testWidgets('fuera de asignado, cotizado y aceptada no muestra nada', (
    tester,
  ) async {
    await abrir(tester, EstadoSolicitud.enProgreso);

    expect(find.byType(SeccionCotizacion), findsNothing);
  });

  testWidgets('si no carga las cotizaciones permite reintentar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          cotizacionesProvider.overrideWith(
            (ref, id) => Future<List<Cotizacion>>.error(StateError('x')),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CotizacionTecnico(
              solicitud: _solicitud(EstadoSolicitud.asignado),
              alCambiar: () => cambios++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reintentar'));
    expect(cambios, 1);
  });

  testWidgets('tema oscuro y texto al 200 % sin desbordes', (tester) async {
    cotizaciones = [
      cotizacionJson(estado: 'rechazada', motivo: 'Muy costosa.'),
    ];
    await abrir(
      tester,
      EstadoSolicitud.asignado,
      tema: AppTheme.oscuro(),
      escalaTexto: 2,
    );
    await llenar(tester, manoDeObra: '1200000', materiales: '650000');

    expect(tester.takeException(), isNull);
  });
}
