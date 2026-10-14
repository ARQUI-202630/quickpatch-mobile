import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/core/config/app_config.dart';
import 'package:quickpatch_mobile/core/realtime/canal_tiempo_real.dart';
import 'package:quickpatch_mobile/core/realtime/mensaje_tiempo_real.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';
import 'package:quickpatch_mobile/features/autenticacion/presentation/controlador_sesion.dart';

import '../../helpers/fakes.dart';

void main() {
  late ConectorWsFalso conector;
  late int tokensInvalidos;

  CanalTiempoReal crear({String? token = 'token-acceso'}) => CanalTiempoReal(
    url: Uri.parse('wss://qa.quickpatch.co/api/v1/realtime'),
    obtenerToken: () => token,
    conectar: conector.call,
    alTokenInvalido: () => tokensInvalidos++,
  );

  setUp(() {
    conector = ConectorWsFalso();
    tokensInvalidos = 0;
  });

  test('envía primero la trama auth y queda en vivo con auth.accepted', () {
    fakeAsync((async) {
      final canal = crear()..iniciar();
      async.flushMicrotasks();

      expect(conector.ultimaUrl.toString(), endsWith('/v1/realtime'));
      expect(conector.ultimaUrl!.query, isEmpty);
      expect(jsonDecode(conector.ultima.enviadas.single), {
        'type': 'auth',
        'token': 'token-acceso',
      });
      expect(canal.estado.value, EstadoCanal.conectando);

      conector.ultima.recibir({
        'type': 'auth.accepted',
        'expiresAt': '2026-10-12T18:00:00Z',
      });
      async.flushMicrotasks();
      expect(canal.estado.value, EstadoCanal.conectado);
      canal.cerrar();
    });
  });

  test('publica los avisos e ignora tramas inválidas o sin tipo', () {
    fakeAsync((async) {
      final canal = crear()..iniciar();
      final avisos = <MensajeTiempoReal>[];
      canal.avisos.listen(avisos.add);
      async.flushMicrotasks();

      conector.ultima
        ..recibir({'type': 'auth.accepted'})
        ..recibirTexto('no es json')
        ..recibirTexto([1, 2, 3])
        ..recibirTexto('[1]')
        ..recibir({'sin': 'tipo'})
        ..recibir({
          'type': 'service-request.status-changed',
          'serviceRequestId': 's-1',
          'status': 'asignado',
          'occurredAt': '2026-10-12T16:10:00Z',
        })
        ..recibir({'type': 'algo.nuevo'});
      async.flushMicrotasks();

      expect(avisos.map((a) => a.tipo), [
        MensajeTiempoReal.cambioDeEstado,
        'algo.nuevo',
      ]);
      expect(avisos.first.cambiaSolicitud('s-1'), isTrue);
      expect(avisos.first.cambiaSolicitud('s-2'), isFalse);
      expect(avisos.last.cambiaSolicitud('s-1'), isFalse);
      canal.cerrar();
    });
  });

  test('reconecta con espera creciente al caerse (1001, 1011, 4004)', () {
    fakeAsync((async) {
      final canal = crear()..iniciar();
      async.flushMicrotasks();
      conector.ultima.cerrarDesdeServidor(1011);
      async.flushMicrotasks();
      expect(canal.estado.value, EstadoCanal.desconectado);

      async.elapse(const Duration(milliseconds: 999));
      expect(conector.conexiones, hasLength(1));
      async.elapse(const Duration(milliseconds: 1));
      expect(conector.conexiones, hasLength(2));

      conector.ultima.cerrarDesdeServidor(4004);
      async.elapse(const Duration(seconds: 1));
      expect(conector.conexiones, hasLength(2));
      async.elapse(const Duration(seconds: 1));
      expect(conector.conexiones, hasLength(3));

      // Al autenticarse vuelve a empezar desde 1 s.
      conector.ultima.recibir({'type': 'auth.accepted'});
      async.flushMicrotasks();
      conector.ultima.cerrarDesdeServidor(1001);
      async.elapse(const Duration(seconds: 1));
      expect(conector.conexiones, hasLength(4));
      canal.cerrar();
    });
  });

  test('si no logra conectar reintenta', () {
    fakeAsync((async) {
      conector.fallar = true;
      final canal = crear()..iniciar();
      async.flushMicrotasks();
      expect(conector.conexiones, isEmpty);
      expect(canal.estado.value, EstadoCanal.desconectado);
      async.elapse(const Duration(seconds: 1));
      expect(conector.conexiones, hasLength(1));
      canal.cerrar();
    });
  });

  for (final codigo in [4000, 4002, 4003]) {
    test('con $codigo no reintenta', () {
      fakeAsync((async) {
        final canal = crear()..iniciar();
        async.flushMicrotasks();
        conector.ultima.cerrarDesdeServidor(codigo);
        async.elapse(const Duration(minutes: 5));
        expect(conector.conexiones, hasLength(1));
        expect(canal.estado.value, EstadoCanal.detenido);
        expect(tokensInvalidos, 0);
      });
    });
  }

  test('con 4001 no reintenta y pide volver a iniciar sesión', () {
    fakeAsync((async) {
      crear().iniciar();
      async.flushMicrotasks();
      conector.ultima.cerrarDesdeServidor(4001);
      async.elapse(const Duration(minutes: 5));
      expect(conector.conexiones, hasLength(1));
      expect(tokensInvalidos, 1);
    });
  });

  test('sin token no se conecta', () {
    fakeAsync((async) {
      final canal = crear(token: null)..iniciar();
      async.flushMicrotasks();
      expect(conector.conexiones, isEmpty);
      expect(canal.estado.value, EstadoCanal.detenido);
    });
  });

  test('cerrar corta la conexión y cancela el reintento', () {
    fakeAsync((async) {
      final canal = crear()..iniciar();
      async.flushMicrotasks();
      final primera = conector.ultima;
      canal.cerrar();
      async.flushMicrotasks();
      expect(primera.cerradaPorApp, isTrue);
      expect(canal.estado.value, EstadoCanal.detenido);
      async.elapse(const Duration(minutes: 5));
      expect(conector.conexiones, hasLength(1));
      canal.iniciar();
      async.flushMicrotasks();
      expect(conector.conexiones, hasLength(1));
    });
  });

  test('esperaCreciente duplica hasta 60 s', () {
    expect(
      [
        for (var i = 0; i < 9; i++)
          CanalTiempoReal.esperaCreciente(i).inSeconds,
      ],
      [1, 2, 4, 8, 16, 32, 60, 60, 60],
    );
  });

  test('urlTiempoReal pasa de http(s) a ws(s) y conserva /api', () {
    expect(
      urlTiempoReal('https://qa.quickpatch.co/api').toString(),
      'wss://qa.quickpatch.co/api/v1/realtime',
    );
    expect(
      urlTiempoReal('http://10.0.2.2:8080/api/').toString(),
      'ws://10.0.2.2:8080/api/v1/realtime',
    );
  });

  group('canalTiempoRealProvider', () {
    Future<ProviderContainer> conSesion(RolUsuario? rol) async {
      final container = ProviderContainer(
        overrides: [
          almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
          conectorWsProvider.overrideWithValue(conector.call),
        ],
      );
      addTearDown(container.dispose);
      if (rol != null) {
        await container
            .read(almacenSesionProvider)
            .guardar(sesionDePrueba(rol: rol));
      }
      await container.read(controladorSesionProvider.future);
      container.listen(canalTiempoRealProvider, (_, _) {});
      await pumpEventQueue();
      return container;
    }

    test('se autentica con el token de la sesión', () async {
      await conSesion(RolUsuario.tecnico);
      expect(jsonDecode(conector.ultima.enviadas.single), {
        'type': 'auth',
        'token': 'token-acceso',
      });
      expect(conector.ultimaUrl!.scheme, 'ws');
    });

    test('con 4001 cierra la sesión', () async {
      final container = await conSesion(RolUsuario.cliente);
      await conector.ultima.cerrarDesdeServidor(4001);
      await pumpEventQueue();
      expect(container.read(controladorSesionProvider).value, isNull);
    });

    test('sin sesión o con rol de administración no se conecta', () async {
      await conSesion(null);
      await conSesion(RolUsuario.adminTenant);
      expect(conector.conexiones, isEmpty);
    });
  });

  group('conectarConDartIo', () {
    late HttpServer servidor;
    late Completer<String?> host;
    late Completer<String> recibido;

    setUp(() async {
      host = Completer();
      recibido = Completer();
      servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      servidor.listen((peticion) async {
        host.complete(peticion.headers.value('host'));
        final ws = await WebSocketTransformer.upgrade(peticion);
        ws.listen((trama) async {
          recibido.complete(trama as String);
          ws.add('{"type":"auth.accepted"}');
          await ws.close(4004);
        });
      });
    });

    tearDown(() => servidor.close(force: true));

    test(
      'envía la cabecera Host, intercambia tramas y lee el cierre',
      () async {
        final conexion = await conectarConDartIo(
          Uri.parse('ws://127.0.0.1:${servidor.port}/api/v1/realtime'),
          const AppConfig(
            entorno: 'qa',
            apiBaseUrl: 'http://127.0.0.1/api',
            canalId: 'quickpatch-mobile',
            hostHeader: 'qa.quickpatch.local',
            certificadoSha256: 'AA:BB',
          ),
        );
        final tramas = <dynamic>[];
        final fin = Completer<void>();
        conexion.tramas.listen(tramas.add, onDone: fin.complete);
        conexion.enviar('{"type":"auth","token":"t"}');

        expect(await host.future, 'qa.quickpatch.local');
        expect(await recibido.future, '{"type":"auth","token":"t"}');
        await fin.future;
        expect(tramas, ['{"type":"auth.accepted"}']);
        expect(conexion.codigoCierre, 4004);
        await conexion.cerrar();
      },
    );

    test('el provider usa la configuración de la app', () async {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              entorno: 'dev',
              apiBaseUrl: 'http://127.0.0.1/api',
              canalId: 'quickpatch-mobile',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final conexion = await container.read(conectorWsProvider)(
        Uri.parse('ws://127.0.0.1:${servidor.port}/api/v1/realtime'),
      );
      conexion.enviar('{}');
      expect(await host.future, '127.0.0.1:${servidor.port}');
      await conexion.cerrar();
    });
  });
}
