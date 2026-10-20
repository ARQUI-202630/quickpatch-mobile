import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/features/solicitudes/data/repositorio_solicitudes.dart';
import 'package:quickpatch_mobile/features/solicitudes/domain/modelos.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/widgets/evidencia_cliente.dart';

import '../../helpers/evidencias.dart';
import '../../helpers/fakes.dart';

/// Fotos del trabajo para el cliente (RF-15, SCRUM-95; service-request 1.7.0).
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

  setUp(() {
    adaptador = AdaptadorFalso((o) {
      if (o.path.endsWith('/file')) return respuestaImagen();
      return respuestaJson({
        'items': [evidenciaJson(), evidenciaJson(id: 'e-2')],
      }, 200);
    });
  });

  Future<void> abrir(
    WidgetTester tester,
    EstadoSolicitud estado, {
    double escalaTexto = 1,
  }) async {
    tester.platformDispatcher.textScaleFactorTestValue = escalaTexto;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          repositorioSolicitudesProvider.overrideWithValue(
            RepositorioSolicitudes(
              Dio(BaseOptions(baseUrl: 'https://qa.quickpatch.internal/api'))
                ..httpClientAdapter = adaptador,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.oscuro(),
          home: Scaffold(
            body: ListView(
              children: [EvidenciaCliente(solicitud: _solicitud(estado))],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder clave(String k) => find.byKey(Key(k));

  testWidgets('antes de iniciar no muestra la sección', (tester) async {
    await abrir(tester, EstadoSolicitud.cotizacionAceptada);

    expect(clave('evidencia-cliente'), findsNothing);
    expect(adaptador.ultima, isNull);
  });

  for (final estado in [EstadoSolicitud.completado, EstadoSolicitud.pagado]) {
    testWidgets('en ${estado.valor} lista las fotos con GET evidence', (
      tester,
    ) async {
      await abrir(tester, estado);

      expect(clave('galeria-evidencias'), findsOneWidget);
      expect(clave('evidencia-e-1'), findsOneWidget);
      expect(clave('evidencia-e-2'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Foto 2 de 2')), findsOneWidget);
    });
  }

  testWidgets('en progreso y sin fotos explica que llegarán', (tester) async {
    adaptador.responder = (o) => respuestaJson({'items': <Object>[]}, 200);
    await abrir(tester, EstadoSolicitud.enProgreso);

    expect(clave('sin-fotos'), findsOneWidget);
  });

  testWidgets('si no carga permite reintentar', (tester) async {
    adaptador.responder = (o) =>
        respuestaJson({'title': 'x', 'status': 500}, 500);
    await abrir(tester, EstadoSolicitud.completado);

    expect(clave('error-evidencias'), findsOneWidget);
    adaptador.responder = (o) => o.path.endsWith('/file')
        ? respuestaImagen()
        : respuestaJson({
            'items': [evidenciaJson()],
          }, 200);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(clave('evidencia-e-1'), findsOneWidget);
  });

  testWidgets('texto al 200 % sin desbordes', (tester) async {
    await abrir(tester, EstadoSolicitud.completado, escalaTexto: 2);

    expect(tester.takeException(), isNull);
  });

  test('la solicitud lee startedAt y completedAt de la versión 1.7.0', () {
    final s = Solicitud.desdeJson({
      'id': 's-1',
      'status': 'completado',
      'categoryId': 'c-1',
      'description': 'Fuga de agua debajo del lavaplatos',
      'location': {'latitude': 4.6765, 'longitude': -74.048},
      'addressText': 'Calle 93 # 13-20',
      'createdAt': '2026-10-20T14:00:00Z',
      'startedAt': '2026-10-20T15:00:00Z',
      'completedAt': '2026-10-20T17:10:00Z',
    });

    expect(s.iniciadaEn, DateTime.utc(2026, 10, 20, 15));
    expect(s.completadaEn, DateTime.utc(2026, 10, 20, 17, 10));
    expect(
      Evidencia.desdeJson(evidenciaJson()).subidaEn,
      DateTime.utc(2026, 10, 20, 16, 40),
    );
  });
}
