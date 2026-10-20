import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/features/solicitudes/data/repositorio_solicitudes.dart';
import 'package:quickpatch_mobile/features/solicitudes/data/selector_fotos.dart';
import 'package:quickpatch_mobile/features/solicitudes/domain/modelos.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/widgets/ejecucion_tecnico.dart';

import '../../helpers/evidencias.dart';
import '../../helpers/fakes.dart';

/// Iniciar, subir fotos y completar desde la app del técnico (RF-14, RF-15,
/// SCRUM-95; contrato service-request 1.7.0).
Solicitud _solicitud(EstadoSolicitud estado, {DateTime? completada}) =>
    Solicitud(
      id: 's-1',
      estado: estado,
      categoriaId: 'c-1',
      descripcion: 'Fuga de agua debajo del lavaplatos',
      ubicacion: const Ubicacion(4.6765, -74.0480),
      direccion: 'Calle 93 # 13-20',
      creadaEn: DateTime.utc(2026, 10, 20, 14),
      completadaEn: completada,
    );

Map<String, dynamic> _problema(
  String tipo,
  int status, {
  Map<String, dynamic>? errores,
}) => {
  'type': 'https://quickpatch.internal/problems/$tipo',
  'title': 'Error',
  'status': status,
  'errors': ?errores,
};

void main() {
  late AdaptadorFalso adaptador;
  late List<Map<String, dynamic>> evidencias;
  late int lecturasEvidencias;
  late int cambios;
  late SelectorFotosFalso selector;
  late List<RequestOptions> peticiones;

  setUp(() {
    evidencias = [];
    lecturasEvidencias = 0;
    cambios = 0;
    peticiones = [];
    selector = SelectorFotosFalso(FotoElegida(pngMinimo, 'trabajo.jpg'));
    adaptador = AdaptadorFalso((o) {
      peticiones.add(o);
      if (o.path.endsWith('/file')) return respuestaImagen();
      if (o.path.endsWith('/evidence')) {
        return respuestaJson(evidenciaJson(id: 'e-nueva'), 201);
      }
      return respuestaJson({'id': 's-1', 'status': 'ok'}, 200);
    });
  });

  Future<void> abrir(
    WidgetTester tester,
    EstadoSolicitud estado, {
    ThemeData? tema,
    double escalaTexto = 1,
    DateTime? completada,
    bool fallarEvidencias = false,
  }) async {
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = escalaTexto;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          evidenciasProvider.overrideWith((ref, id) async {
            lecturasEvidencias++;
            if (fallarEvidencias) throw StateError('sin red');
            return evidencias.map(Evidencia.desdeJson).toList();
          }),
          selectorFotosProvider.overrideWithValue(selector),
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
                EjecucionTecnico(
                  solicitud: _solicitud(estado, completada: completada),
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

  bool habilitado(WidgetTester tester, String k) =>
      tester.widget<ButtonStyleButton>(clave(k)).onPressed != null;

  Future<void> tocar(WidgetTester tester, String k) async {
    await tester.ensureVisible(clave(k));
    await tester.tap(clave(k));
    await tester.pump();
  }

  /// Tras un paso exitoso el botón sigue ocupado hasta que la pantalla
  /// recarga: se avanza el tiempo sin esperar a que todo se detenga.
  Future<void> esperar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  List<RequestOptions> posts() =>
      peticiones.where((o) => o.method == 'POST').toList();

  group('antes de iniciar', () {
    for (final estado in [EstadoSolicitud.asignado, EstadoSolicitud.cotizado]) {
      testWidgets('en ${estado.valor} el botón está deshabilitado', (
        tester,
      ) async {
        await abrir(tester, estado);

        expect(habilitado(tester, 'boton-iniciar-servicio'), isFalse);
        expect(find.textContaining('acepte tu cotización'), findsOneWidget);
      });
    }

    testWidgets('fuera de los estados del técnico no muestra nada', (
      tester,
    ) async {
      await abrir(tester, EstadoSolicitud.cancelado);

      expect(clave('boton-iniciar-servicio'), findsNothing);
      expect(EjecucionTecnico.aplica(EstadoSolicitud.pagado), isFalse);
    });
  });

  group('iniciar', () {
    testWidgets('confirma, llama a start y recarga', (tester) async {
      await abrir(tester, EstadoSolicitud.cotizacionAceptada);

      await tocar(tester, 'boton-iniciar-servicio');
      await tester.pumpAndSettle();
      expect(find.text('¿Iniciar el servicio?'), findsOneWidget);
      await tester.tap(clave('confirmar-iniciar'));
      await esperar(tester);

      expect(posts().single.path, '/v1/service-requests/s-1/start');
      expect(find.textContaining('Iniciaste el servicio'), findsOneWidget);
      expect(cambios, 1);
      expect(habilitado(tester, 'boton-iniciar-servicio'), isFalse);
    });

    testWidgets('al volver del diálogo no llama al backend', (tester) async {
      await abrir(tester, EstadoSolicitud.cotizacionAceptada);

      await tocar(tester, 'boton-iniciar-servicio');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      expect(posts(), isEmpty);
      expect(habilitado(tester, 'boton-iniciar-servicio'), isTrue);
    });

    testWidgets('un 409 avisa y recarga', (tester) async {
      adaptador.responder = (o) =>
          respuestaJson(_problema('transicion-invalida', 409), 409);
      await abrir(tester, EstadoSolicitud.cotizacionAceptada);

      await tocar(tester, 'boton-iniciar-servicio');
      await tester.pumpAndSettle();
      await tester.tap(clave('confirmar-iniciar'));
      await tester.pumpAndSettle();

      expect(find.text(avisoCambio), findsOneWidget);
      expect(cambios, 1);
      expect(habilitado(tester, 'boton-iniciar-servicio'), isTrue);
    });

    testWidgets('otro error se muestra y permite reintentar', (tester) async {
      adaptador.responder = (o) =>
          respuestaJson(_problema('error-interno', 500), 500);
      await abrir(tester, EstadoSolicitud.cotizacionAceptada);

      await tocar(tester, 'boton-iniciar-servicio');
      await tester.pumpAndSettle();
      await tester.tap(clave('confirmar-iniciar'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(cambios, 0);
      expect(habilitado(tester, 'boton-iniciar-servicio'), isTrue);
    });
  });

  group('en progreso', () {
    testWidgets('sin fotos no deja completar', (tester) async {
      await abrir(tester, EstadoSolicitud.enProgreso);

      expect(
        tester.widget<Text>(clave('contador-fotos')).data,
        '0 de 10 fotos',
      );
      expect(habilitado(tester, 'boton-completar'), isFalse);
      expect(clave('ayuda-completar'), findsOneWidget);
      expect(clave('galeria-evidencias'), findsNothing);
    });

    testWidgets('sube la foto elegida en el campo file y recarga las fotos', (
      tester,
    ) async {
      await abrir(tester, EstadoSolicitud.enProgreso);

      await tocar(tester, 'boton-elegir-foto');
      await tester.pumpAndSettle();

      expect(selector.origenes, [OrigenFoto.galeria]);
      final subida = posts().single;
      expect(subida.path, '/v1/service-requests/s-1/evidence');
      final formulario = subida.data as FormData;
      expect(formulario.files.single.key, 'file');
      expect(formulario.files.single.value.filename, 'trabajo.jpg');
      expect(find.text('Foto subida.'), findsOneWidget);
      expect(lecturasEvidencias, 2);
    });

    testWidgets('tomar foto usa la cámara', (tester) async {
      await abrir(tester, EstadoSolicitud.enProgreso);

      await tocar(tester, 'boton-tomar-foto');
      await tester.pumpAndSettle();

      expect(selector.origenes, [OrigenFoto.camara]);
      expect(posts(), hasLength(1));
    });

    testWidgets('si vuelve sin elegir no sube nada', (tester) async {
      selector.foto = null;
      await abrir(tester, EstadoSolicitud.enProgreso);

      await tocar(tester, 'boton-elegir-foto');
      await tester.pumpAndSettle();

      expect(posts(), isEmpty);
    });

    testWidgets('una foto de más de 10 MB no se sube', (tester) async {
      selector.foto = FotoElegida(
        Uint8List(LimitesEvidencia.bytesMaximos + 1),
        'enorme.jpg',
      );
      await abrir(tester, EstadoSolicitud.enProgreso);

      await tocar(tester, 'boton-elegir-foto');
      await tester.pumpAndSettle();

      expect(posts(), isEmpty);
      expect(find.textContaining('más de 10 MB'), findsOneWidget);
    });

    testWidgets('un 400 muestra el error del campo file', (tester) async {
      adaptador.responder = (o) => respuestaJson(
        _problema(
          'validacion',
          400,
          errores: {
            'file': ['La foto debe ser JPEG, PNG o WebP.'],
          },
        ),
        400,
      );
      await abrir(tester, EstadoSolicitud.enProgreso);

      await tocar(tester, 'boton-elegir-foto');
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(clave('error-foto')).data,
        'La foto debe ser JPEG, PNG o WebP.',
      );
      expect(clave('progreso-subida'), findsNothing);
    });

    testWidgets('un 409 limite-de-evidencias avisa y recarga las fotos', (
      tester,
    ) async {
      adaptador.responder = (o) =>
          respuestaJson(_problema('limite-de-evidencias', 409), 409);
      await abrir(tester, EstadoSolicitud.enProgreso);

      await tocar(tester, 'boton-elegir-foto');
      await tester.pumpAndSettle();

      expect(find.textContaining('Ya subiste las 10 fotos'), findsOneWidget);
      expect(lecturasEvidencias, 2);
      expect(cambios, 0);
    });

    testWidgets(
      'un 409 transicion-invalida al subir avisa y recarga el servicio',
      (tester) async {
        adaptador.responder = (o) =>
            respuestaJson(_problema('transicion-invalida', 409), 409);
        await abrir(tester, EstadoSolicitud.enProgreso);

        await tocar(tester, 'boton-elegir-foto');
        await tester.pumpAndSettle();

        expect(find.text(avisoCambio), findsOneWidget);
        expect(cambios, 1);
      },
    );

    testWidgets('con 10 fotos ya no ofrece subir más', (tester) async {
      evidencias = [for (var i = 0; i < 10; i++) evidenciaJson(id: 'e-$i')];
      await abrir(tester, EstadoSolicitud.enProgreso);

      expect(clave('maximo-fotos'), findsOneWidget);
      expect(clave('boton-tomar-foto'), findsNothing);
      expect(
        tester.widget<Text>(clave('contador-fotos')).data,
        '10 de 10 fotos',
      );
      expect(find.byKey(const Key('evidencia-e-9')), findsOneWidget);
    });

    testWidgets('con una foto confirma, completa y recarga', (tester) async {
      evidencias = [evidenciaJson()];
      await abrir(tester, EstadoSolicitud.enProgreso);

      expect(habilitado(tester, 'boton-completar'), isTrue);
      await tocar(tester, 'boton-completar');
      await tester.pumpAndSettle();
      await tester.tap(clave('confirmar-completar'));
      await esperar(tester);

      expect(posts().single.path, '/v1/service-requests/s-1/complete');
      expect(find.textContaining('Completaste el servicio'), findsOneWidget);
      expect(cambios, 1);
      expect(habilitado(tester, 'boton-completar'), isFalse);
    });

    testWidgets('un 422 pide una foto y recarga las fotos', (tester) async {
      evidencias = [evidenciaJson()];
      adaptador.responder = (o) =>
          respuestaJson(_problema('evidencia-requerida', 422), 422);
      await abrir(tester, EstadoSolicitud.enProgreso);

      await tocar(tester, 'boton-completar');
      await tester.pumpAndSettle();
      await tester.tap(clave('confirmar-completar'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(clave('error-foto')).data,
        'Sube al menos una foto del trabajo.',
      );
      expect(lecturasEvidencias, 2);
      expect(cambios, 0);
    });

    testWidgets('un 409 al completar avisa y recarga el servicio', (
      tester,
    ) async {
      evidencias = [evidenciaJson()];
      adaptador.responder = (o) =>
          respuestaJson(_problema('transicion-invalida', 409), 409);
      await abrir(tester, EstadoSolicitud.enProgreso);

      await tocar(tester, 'boton-completar');
      await tester.pumpAndSettle();
      await tester.tap(clave('confirmar-completar'));
      await tester.pumpAndSettle();

      expect(find.text(avisoCambio), findsOneWidget);
      expect(cambios, 1);
    });

    testWidgets('si no carga las fotos permite reintentar', (tester) async {
      await abrir(tester, EstadoSolicitud.enProgreso, fallarEvidencias: true);

      expect(clave('error-evidencias'), findsOneWidget);
      expect(habilitado(tester, 'boton-completar'), isFalse);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(lecturasEvidencias, 2);
    });

    testWidgets('la miniatura se descarga con la sesión y se ve completa', (
      tester,
    ) async {
      evidencias = [evidenciaJson()];
      await abrir(tester, EstadoSolicitud.enProgreso);

      final descarga = peticiones.singleWhere((o) => o.path.endsWith('/file'));
      expect(descarga.path, '/v1/service-requests/s-1/evidence/e-1/file');
      expect(descarga.responseType, ResponseType.bytes);
      await tester.tap(clave('evidencia-e-1'));
      await tester.pumpAndSettle();
      expect(clave('foto-completa'), findsOneWidget);
      await tester.tap(clave('cerrar-foto'));
      await tester.pumpAndSettle();
      expect(clave('foto-completa'), findsNothing);
    });

    testWidgets('si una miniatura no carga, tocarla la vuelve a pedir', (
      tester,
    ) async {
      evidencias = [evidenciaJson()];
      adaptador.responder = (o) {
        peticiones.add(o);
        return respuestaJson(_problema('no-encontrado', 404), 404);
      };
      await abrir(tester, EstadoSolicitud.enProgreso);

      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      await tester.tap(clave('evidencia-e-1'));
      await tester.pumpAndSettle();
      expect(peticiones.where((o) => o.path.endsWith('/file')), hasLength(2));
    });

    testWidgets('tema oscuro y texto al 200 % sin desbordes', (tester) async {
      evidencias = [evidenciaJson(), evidenciaJson(id: 'e-2')];
      await abrir(
        tester,
        EstadoSolicitud.enProgreso,
        tema: AppTheme.oscuro(),
        escalaTexto: 2,
      );

      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('completado muestra la fecha y las fotos', (tester) async {
    evidencias = [evidenciaJson()];
    await abrir(
      tester,
      EstadoSolicitud.completado,
      completada: DateTime(2026, 10, 20, 17, 10),
    );

    expect(clave('servicio-completado'), findsOneWidget);
    expect(find.textContaining('20/10/2026 17:10'), findsOneWidget);
    expect(clave('galeria-evidencias'), findsOneWidget);
    expect(clave('boton-completar'), findsNothing);
  });
}
