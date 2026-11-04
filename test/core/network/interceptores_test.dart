import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/core/config/app_config.dart';
import 'package:quickpatch_mobile/core/network/cliente_api.dart';
import 'package:quickpatch_mobile/core/network/interceptores.dart';

import '../../helpers/fakes.dart';

void main() {
  late AdaptadorFalso adaptador;
  late String? token;
  late int noAutenticado;
  late Dio dio;

  setUp(() {
    adaptador = AdaptadorFalso((_) => respuestaJson({'ok': true}, 200));
    token = 'abc';
    noAutenticado = 0;
    dio = crearClienteApi(
      const AppConfig(
        entorno: 'test',
        apiBaseUrl: 'https://gw/api',
        canalId: 'canal-1',
      ),
      [
        InterceptorCorrelacion(),
        InterceptorAutenticacion(
          obtenerToken: () => token,
          canalId: 'canal-1',
          alNoAutenticado: () => noAutenticado++,
        ),
      ],
    )..httpClientAdapter = adaptador;
  });

  test(
    'petición autenticada lleva Bearer y correlación, nunca tenant',
    () async {
      await dio.get<void>('/v1/users/me');
      final h = adaptador.ultima!.headers;
      expect(adaptador.ultima!.uri.toString(), 'https://gw/api/v1/users/me');
      expect(h['Authorization'], 'Bearer abc');
      expect(h['X-Correlation-Id'], isA<String>());
      expect(h.containsKey('X-Channel-Id'), isFalse);
      expect(h.keys.any((k) => k.toLowerCase().contains('tenant')), isFalse);
    },
  );

  test('sin token no agrega Authorization', () async {
    token = null;
    await dio.get<void>('/v1/users/me');
    expect(adaptador.ultima!.headers.containsKey('Authorization'), isFalse);
  });

  test('petición pública lleva canal y no token', () async {
    await dio.post<void>('/v1/auth/login', options: opcionesPublicas());
    final h = adaptador.ultima!.headers;
    expect(h['X-Channel-Id'], 'canal-1');
    expect(h.containsKey('Authorization'), isFalse);
  });

  test('conserva un X-Correlation-Id existente y la Idempotency-Key', () async {
    final opciones = opcionesIdempotentes('clave-1')
      ..headers!['X-Correlation-Id'] = 'propio';
    await dio.post<void>('/v1/service-requests', options: opciones);
    expect(adaptador.ultima!.headers['X-Correlation-Id'], 'propio');
    expect(adaptador.ultima!.headers['Idempotency-Key'], 'clave-1');
  });

  test('401 en petición autenticada avisa una vez; en pública no', () async {
    adaptador.responder = (_) =>
        respuestaJson({'code': 'UNAUTHENTICATED'}, 401);
    await expectLater(
      dio.get<void>('/v1/users/me'),
      throwsA(isA<DioException>()),
    );
    expect(noAutenticado, 1);

    adaptador.responder = (_) =>
        respuestaJson({'code': 'INVALID_CREDENTIALS'}, 401);
    await expectLater(
      dio.post<void>('/v1/auth/login', options: opcionesPublicas()),
      throwsA(isA<DioException>()),
    );
    expect(noAutenticado, 1);
  });
}
