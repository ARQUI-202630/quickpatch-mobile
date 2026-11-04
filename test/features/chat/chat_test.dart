import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quickpatch_mobile/app/router/rutas.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/core/realtime/canal_tiempo_real.dart';
import 'package:quickpatch_mobile/core/realtime/mensaje_tiempo_real.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/features/chat/data/repositorio_chat.dart';
import 'package:quickpatch_mobile/features/chat/presentation/paginas/chat_page.dart';
import 'package:quickpatch_mobile/features/solicitudes/domain/modelos.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/widgets/boton_chat.dart';

import '../../helpers/fakes.dart';

/// Chat de la solicitud (RF-37, SCRUM-482): communication.v1.yaml 1.3.0 y la
/// trama `chat.message` de realtime.v1.yaml 1.1.0. La sesión de prueba es la
/// del usuario `u-1`.
Map<String, dynamic> _mensaje(
  String id, {
  String autor = 't-1',
  String rol = 'tecnico',
  String texto = 'Voy en camino',
  String enviado = '2026-10-21T15:00:00Z',
}) => {
  'id': id,
  'authorId': autor,
  'authorRole': rol,
  'text': texto,
  'sentAt': enviado,
};

Map<String, dynamic> _pagina(
  List<Map<String, dynamic>> items, {
  int page = 1,
  int? total,
  bool escribible = true,
}) => {
  'items': items,
  'page': page,
  'size': 30,
  'totalItems': total ?? items.length,
  'writable': escribible,
};

ResponseBody _problema(int status, String tipo) => respuestaJson({
  'type': 'https://quickpatch.internal/problems/$tipo',
  'title': tipo,
  'status': status,
}, status);

Solicitud _solicitud(EstadoSolicitud estado, {String? tecnicoId}) => Solicitud(
  id: 's-1',
  estado: estado,
  categoriaId: 'c-1',
  descripcion: 'Fuga',
  ubicacion: const Ubicacion(4.65, -74.08),
  direccion: 'Calle 45 # 13-20',
  creadaEn: DateTime.utc(2026, 10, 21),
  tecnicoId: tecnicoId,
);

void main() {
  late List<RequestOptions> peticiones;
  late ResponseBody Function(RequestOptions) listar;
  late ResponseBody Function(RequestOptions) enviar;
  late ConectorWsFalso conector;

  setUp(() {
    peticiones = [];
    listar = (o) => respuestaJson(
      _pagina([
        _mensaje('m-2', enviado: '2026-10-21T15:05:00Z'),
        _mensaje(
          'm-1',
          autor: 'u-1',
          rol: 'cliente',
          texto: '¿A qué hora llega?',
        ),
      ]),
      200,
    );
    enviar = (o) => respuestaJson(
      _mensaje(
        'm-3',
        autor: 'u-1',
        rol: 'cliente',
        texto: (o.data as Map<String, dynamic>)['text'] as String,
        enviado: '2026-10-21T15:10:00Z',
      ),
      201,
    );
    conector = ConectorWsFalso();
  });

  Finder clave(String k) => find.byKey(Key(k));

  Future<void> abrir(WidgetTester tester, {Widget? pantalla}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final memoria = AlmacenSeguroEnMemoria();
    await AlmacenSesion(memoria).guardar(sesionDePrueba());
    final dio = Dio(BaseOptions(baseUrl: 'https://qa.quickpatch.internal/api'))
      ..httpClientAdapter = AdaptadorFalso((o) {
        peticiones.add(o);
        return o.method == 'POST' ? enviar(o) : listar(o);
      });
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          almacenSeguroProvider.overrideWithValue(memoria),
          repositorioChatProvider.overrideWithValue(RepositorioChat(dio)),
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
          home: pantalla ?? const ChatPage(solicitudId: 's-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> conectar(WidgetTester tester) async {
    conector.ultima.recibir({'type': 'auth.accepted'});
    await tester.pumpAndSettle();
  }

  Future<void> trama(WidgetTester tester, Map<String, dynamic> json) async {
    conector.ultima.recibir(json);
    await tester.pumpAndSettle();
  }

  testWidgets('muestra el historial con el más reciente abajo', (tester) async {
    await abrir(tester);

    final pedido = peticiones.single;
    expect(pedido.path, '/v1/service-requests/s-1/messages');
    expect(pedido.queryParameters, {'page': 1, 'size': 30});
    expect(find.text('¿A qué hora llega?'), findsOneWidget);
    expect(find.text('Voy en camino'), findsOneWidget);
    expect(
      tester.getTopLeft(clave('mensaje-m-1')).dy,
      lessThan(tester.getTopLeft(clave('mensaje-m-2')).dy),
    );
    // El propio va a la derecha; el del técnico, a la izquierda.
    expect(
      tester.getTopRight(clave('mensaje-m-1')).dx,
      greaterThan(tester.getTopRight(clave('mensaje-m-2')).dx),
    );
    expect(clave('chat-texto'), findsOneWidget);
    expect(clave('chat-anteriores'), findsNothing);
  });

  testWidgets('envía el texto sin espacios y lo agrega a la conversación', (
    tester,
  ) async {
    await abrir(tester);

    await tester.enterText(clave('chat-texto'), '  Ya abro la puerta  ');
    await tester.tap(clave('chat-enviar'));
    await tester.pumpAndSettle();

    final post = peticiones.last;
    expect(post.method, 'POST');
    expect(post.path, '/v1/service-requests/s-1/messages');
    expect(post.data, {'text': 'Ya abro la puerta'});
    expect(clave('mensaje-m-3'), findsOneWidget);
    expect(
      tester.widget<TextField>(clave('chat-texto')).controller!.text,
      isEmpty,
    );
  });

  testWidgets('un texto vacío no se envía', (tester) async {
    await abrir(tester);

    await tester.enterText(clave('chat-texto'), '   ');
    await tester.tap(clave('chat-enviar'));
    await tester.pumpAndSettle();

    expect(peticiones.where((p) => p.method == 'POST'), isEmpty);
  });

  testWidgets(
    'agrega los mensajes del canal sin repetir e ignora otros chats',
    (tester) async {
      await abrir(tester);
      await conectar(tester);
      final nuevo = _mensaje(
        'm-4',
        texto: 'Llego en 10 minutos',
        enviado: '2026-10-21T15:20:00Z',
      );

      await trama(tester, {
        'type': 'chat.message',
        'serviceRequestId': 's-1',
        'message': nuevo,
      });
      await trama(tester, {
        'type': 'chat.message',
        'serviceRequestId': 's-1',
        'message': nuevo,
      });
      await trama(tester, {
        'type': 'chat.message',
        'serviceRequestId': 's-2',
        'message': _mensaje('m-5', texto: 'De otra solicitud'),
      });
      // Una trama incompleta no rompe la pantalla.
      await trama(tester, {
        'type': 'chat.message',
        'serviceRequestId': 's-1',
        'message': {'id': 'm-6'},
      });

      expect(find.text('Llego en 10 minutos'), findsOneWidget);
      expect(find.text('De otra solicitud'), findsNothing);
      expect(clave('mensaje-m-6'), findsNothing);
      // Con el canal conectado no hace falta volver a pedir el historial.
      expect(peticiones, hasLength(1));
    },
  );

  testWidgets('un cambio de estado vuelve a pedir el historial y lo cierra', (
    tester,
  ) async {
    await abrir(tester);
    await conectar(tester);
    listar = (o) =>
        respuestaJson(_pagina([_mensaje('m-2')], escribible: false), 200);

    await trama(tester, {
      'type': 'service-request.status-changed',
      'serviceRequestId': 's-1',
      'status': 'completado',
    });

    expect(peticiones, hasLength(2));
    expect(clave('chat-solo-lectura'), findsOneWidget);
    expect(clave('chat-texto'), findsNothing);
  });

  testWidgets('sin canal consulta el historial cada 30 s (RNF-06)', (
    tester,
  ) async {
    await abrir(tester);

    await tester.pump(MensajeTiempoReal.intervaloRespaldo);
    await tester.pumpAndSettle();
    expect(peticiones, hasLength(2));

    await conectar(tester);
    await tester.pump(MensajeTiempoReal.intervaloRespaldo);
    await tester.pumpAndSettle();
    expect(peticiones, hasLength(2));
  });

  testWidgets('en solo lectura muestra el historial sin el campo de texto', (
    tester,
  ) async {
    listar = (o) => respuestaJson(_pagina(const [], escribible: false), 200);

    await abrir(tester);

    expect(clave('chat-vacio'), findsOneWidget);
    expect(find.text('No hubo mensajes en este servicio.'), findsOneWidget);
    expect(clave('chat-solo-lectura'), findsOneWidget);
    expect(clave('chat-texto'), findsNothing);
  });

  for (final (tipo, aviso) in [
    ('chat-cerrado', 'La solicitud terminó: el chat quedó de solo lectura.'),
    (
      'chat-no-disponible',
      'La solicitud no tiene un técnico asignado en este momento.',
    ),
  ]) {
    testWidgets('409 $tipo cierra el campo y lo explica', (tester) async {
      enviar = (o) => _problema(409, tipo);
      await abrir(tester);

      await tester.enterText(clave('chat-texto'), 'Hola');
      await tester.tap(clave('chat-enviar'));
      await tester.pumpAndSettle();

      expect(find.text(aviso), findsOneWidget);
      expect(clave('chat-solo-lectura'), findsOneWidget);
    });
  }

  testWidgets('si falla el envío conserva el texto para reintentar', (
    tester,
  ) async {
    enviar = (o) => _problema(503, 'servicio-no-disponible');
    await abrir(tester);

    await tester.enterText(clave('chat-texto'), 'Hola');
    await tester.tap(clave('chat-enviar'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      tester.widget<TextField>(clave('chat-texto')).controller!.text,
      'Hola',
    );
  });

  testWidgets('404 muestra el error y permite reintentar', (tester) async {
    listar = (o) => _problema(404, 'no-encontrado');
    await abrir(tester);

    expect(clave('chat-error'), findsOneWidget);
    expect(find.text('No encontramos lo que buscas.'), findsOneWidget);

    listar = (o) => respuestaJson(_pagina([_mensaje('m-2')]), 200);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(clave('mensaje-m-2'), findsOneWidget);
  });

  testWidgets('carga los mensajes anteriores por páginas', (tester) async {
    listar = (o) => o.queryParameters['page'] == 1
        ? respuestaJson(
            _pagina([
              _mensaje('m-31', enviado: '2026-10-21T16:00:00Z'),
            ], total: 31),
            200,
          )
        : respuestaJson(
            _pagina([_mensaje('m-1', texto: 'El primero')], page: 2, total: 31),
            200,
          );
    await abrir(tester);

    await tester.tap(clave('chat-anteriores'));
    await tester.pumpAndSettle();

    expect(peticiones.last.queryParameters, {'page': 2, 'size': 30});
    expect(find.text('El primero'), findsOneWidget);
    expect(clave('chat-anteriores'), findsNothing);
  });

  group('BotonChat', () {
    test('aparece desde que hay técnico asignado', () {
      expect(
        BotonChat.aplica(_solicitud(EstadoSolicitud.buscandoTecnico)),
        isFalse,
      );
      expect(BotonChat.aplica(_solicitud(EstadoSolicitud.enEspera)), isFalse);
      for (final estado in [
        EstadoSolicitud.asignado,
        EstadoSolicitud.cotizado,
        EstadoSolicitud.cotizacionAceptada,
        EstadoSolicitud.enProgreso,
        EstadoSolicitud.completado,
        EstadoSolicitud.pagado,
      ]) {
        expect(BotonChat.aplica(_solicitud(estado)), isTrue, reason: '$estado');
      }
      expect(BotonChat.aplica(_solicitud(EstadoSolicitud.cancelado)), isFalse);
      expect(
        BotonChat.aplica(
          _solicitud(EstadoSolicitud.cancelado, tecnicoId: 't-1'),
        ),
        isTrue,
      );
    });

    testWidgets('abre el chat de la solicitud', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: BotonChat(solicitudId: 's-1', con: 'el técnico'),
            ),
          ),
          GoRoute(
            path: Rutas.chatSolicitudPatron,
            builder: (context, state) =>
                ChatPage(solicitudId: state.pathParameters['id']!),
          ),
        ],
      );
      addTearDown(router.dispose);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final memoria = AlmacenSeguroEnMemoria();
      await AlmacenSesion(memoria).guardar(sesionDePrueba());
      final dio = Dio()
        ..httpClientAdapter = AdaptadorFalso((o) {
          peticiones.add(o);
          return listar(o);
        });
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            almacenSeguroProvider.overrideWithValue(memoria),
            repositorioChatProvider.overrideWithValue(RepositorioChat(dio)),
            conectorWsProvider.overrideWithValue(conector.call),
          ],
          child: MaterialApp.router(
            theme: AppTheme.claro(),
            routerConfig: router,
          ),
        ),
      );

      expect(find.text('Chat con el técnico'), findsOneWidget);
      await tester.tap(clave('boton-chat'));
      await tester.pumpAndSettle();

      expect(find.text('Chat del servicio'), findsOneWidget);
      expect(peticiones.single.path, '/v1/service-requests/s-1/messages');
    });
  });

  test('MensajeTiempoReal lee la trama chat.message', () {
    final m = MensajeTiempoReal.desdeJson(
      jsonDecode(
        jsonEncode({
          'type': 'chat.message',
          'serviceRequestId': 's-1',
          'message': _mensaje('m-1'),
          'occurredAt': '2026-10-21T15:00:00Z',
        }),
      ) as Map<String, dynamic>,
    )!;

    expect(m.esChatDe('s-1'), isTrue);
    expect(m.esChatDe('s-2'), isFalse);
    expect(m.cambiaSolicitud('s-1'), isFalse);
    expect(m.mensajeChat!['text'], 'Voy en camino');
    expect(
      MensajeTiempoReal.desdeJson({
        'type': 'chat.message',
        'serviceRequestId': 's-1',
      })!.esChatDe('s-1'),
      isFalse,
    );
  });
}
