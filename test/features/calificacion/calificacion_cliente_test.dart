import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/core/errors/codigo_error.dart';
import 'package:quickpatch_mobile/features/calificacion/data/repositorio_calificacion.dart';
import 'package:quickpatch_mobile/features/calificacion/presentation/widgets/calificacion_cliente.dart';
import 'package:quickpatch_mobile/features/solicitudes/domain/modelos.dart';

import '../../helpers/fakes.dart';

/// SCRUM-86: calificación del servicio pagado, con
/// `POST /v1/service-requests/{id}/rating` (service-request 1.10.0).
const _problemas = 'https://quickpatch.internal/problems';

Map<String, dynamic> _registrada({int score = 4, String? comment}) => {
  'serviceRequestId': 's-1',
  'score': score,
  'comment': comment,
  'ratedAt': '2026-10-08T15:20:00Z',
};

void main() {
  late List<RequestOptions> envios;
  late ResponseBody Function(RequestOptions) responder;
  late int cambios;

  setUp(() {
    envios = [];
    cambios = 0;
    responder = (o) => respuestaJson(_registrada(), 201);
  });

  Finder clave(String k) => find.byKey(Key(k));

  Future<void> abrir(
    WidgetTester tester, {
    ThemeData? tema,
    double escalaTexto = 1,
  }) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = AdaptadorFalso((o) {
        envios.add(o);
        return responder(o);
      });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositorioCalificacionProvider.overrideWithValue(
            RepositorioCalificacion(dio),
          ),
        ],
        child: MaterialApp(
          theme: tema,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CalificacionCliente(
                solicitud: Solicitud(
                  id: 's-1',
                  estado: EstadoSolicitud.pagado,
                  categoriaId: 'c-1',
                  descripcion: 'Fuga de agua',
                  ubicacion: const Ubicacion(4.6765, -74.0480),
                  direccion: 'Calle 93 # 13-20',
                  creadaEn: DateTime.utc(2026, 10, 7, 15),
                ),
                alCambiar: () => cambios++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> calificar(WidgetTester tester, {int estrellas = 4}) async {
    await tester.tap(clave('estrella-$estrellas'));
    await tester.pump();
    await tester.tap(clave('boton-calificar'));
    await tester.pumpAndSettle();
  }

  test('solo aplica en pagado (RN-R3)', () {
    for (final estado in EstadoSolicitud.values) {
      expect(
        CalificacionCliente.aplica(estado),
        estado == EstadoSolicitud.pagado,
      );
    }
  });

  test('reconoce los errores de la calificación', () {
    expect(
      CodigoError.desdeTipo('$_problemas/ya-calificada'),
      CodigoError.alreadyRated,
    );
    expect(
      CodigoError.desdeTipo('$_problemas/transicion-invalida'),
      CodigoError.invalidStateTransition,
    );
  });

  testWidgets('sin estrellas no se puede enviar', (tester) async {
    await abrir(tester);

    await tester.tap(clave('boton-calificar'));
    await tester.pumpAndSettle();
    expect(envios, isEmpty);
  });

  testWidgets('cada estrella tiene un objetivo táctil y su etiqueta', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.byTooltip('1 de 5 estrellas'), findsOneWidget);
    expect(find.byTooltip('5 de 5 estrellas'), findsOneWidget);
    final tamano = tester.getSize(clave('estrella-3'));
    expect(tamano.width, greaterThanOrEqualTo(48));
    expect(tamano.height, greaterThanOrEqualTo(48));
  });

  testWidgets('envía el puntaje y el comentario, y muestra lo registrado', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    responder = (o) =>
        respuestaJson(_registrada(comment: 'Excelente trabajo.'), 201);
    await abrir(tester);

    await tester.enterText(clave('campo-comentario'), '  Excelente trabajo.  ');
    await calificar(tester);

    expect(envios.single.path, contains('/v1/service-requests/s-1/rating'));
    expect(envios.single.data, {'score': 4, 'comment': 'Excelente trabajo.'});
    expect(clave('calificacion-registrada'), findsOneWidget);
    expect(clave('calificacion-cliente'), findsNothing);
    expect(find.text('Tu calificación'), findsOneWidget);
    expect(find.text('Excelente trabajo.'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
    // La tarjeta une la semántica de su contenido en un solo nodo.
    expect(
      find.bySemanticsLabel(RegExp('Calificación: 4 de 5')),
      findsOneWidget,
    );
    semantica.dispose();
  });

  testWidgets('sin comentario no envía el campo', (tester) async {
    await abrir(tester);

    await calificar(tester);

    expect(envios.single.data, {'score': 4});
    expect(clave('comentario-registrado'), findsNothing);
  });

  testWidgets('el comentario no pasa de 500 caracteres', (tester) async {
    await abrir(tester);

    expect(find.text('0/500'), findsOneWidget);
    await tester.enterText(clave('campo-comentario'), 'a' * 600);
    await tester.pump();
    expect(find.text('500/500'), findsOneWidget);
  });

  testWidgets('409 ya-calificada confirma que ya existe', (tester) async {
    responder = (o) =>
        respuestaJson({'type': '$_problemas/ya-calificada'}, 409);
    await abrir(tester);

    await calificar(tester);

    expect(clave('calificacion-existente'), findsOneWidget);
    expect(find.text('Ya calificaste este servicio.'), findsOneWidget);
    expect(clave('calificacion-cliente'), findsNothing);
    expect(cambios, 0);
  });

  testWidgets('409 transicion-invalida recarga la solicitud', (tester) async {
    responder = (o) =>
        respuestaJson({'type': '$_problemas/transicion-invalida'}, 409);
    await abrir(tester);

    await calificar(tester);

    expect(cambios, 1);
    expect(clave('mensaje-error'), findsOneWidget);
  });

  testWidgets('el error de validación se muestra en el comentario', (
    tester,
  ) async {
    responder = (o) => respuestaJson({
      'type': '$_problemas/validacion',
      'errors': {
        'comment': ['Máximo 500 caracteres.'],
      },
    }, 400);
    await abrir(tester);

    await calificar(tester);

    expect(find.text('Máximo 500 caracteres.'), findsOneWidget);
    expect(clave('mensaje-error'), findsNothing);
  });

  testWidgets('un error general permite volver a enviar', (tester) async {
    responder = (o) => respuestaJson(<String, dynamic>{}, 503);
    await abrir(tester);

    await calificar(tester);
    expect(clave('mensaje-error'), findsOneWidget);

    responder = (o) => respuestaJson(_registrada(), 201);
    await tester.tap(clave('boton-calificar'));
    await tester.pumpAndSettle();
    expect(clave('calificacion-registrada'), findsOneWidget);
  });

  testWidgets('tema oscuro y texto al 200 % sin desbordes', (tester) async {
    await abrir(tester, tema: AppTheme.oscuro(), escalaTexto: 2);
    expect(tester.takeException(), isNull);
    expect(clave('boton-calificar'), findsOneWidget);
  });
}
