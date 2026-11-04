import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// Clave de `RequestOptions.extra` que marca una petición pública (sin token).
const extraPublico = 'publico';

/// `Options` para una petición pública: registro, login y catálogos
/// públicos. Llevan `X-Channel-Id` en lugar del token (DD, sección 8.1).
Options opcionesPublicas() => Options(extra: {extraPublico: true});

/// `Options` con `Idempotency-Key`, para crear solicitud y pagar.
/// Reutiliza la misma [clave] si el usuario reintenta la misma operación.
Options opcionesIdempotentes(String clave) =>
    Options(headers: {'Idempotency-Key': clave});

/// Agrega `X-Correlation-Id` a cada petición (AC7-E4).
class InterceptorCorrelacion extends Interceptor {
  InterceptorCorrelacion([Uuid uuid = const Uuid()]) : _uuid = uuid;

  final Uuid _uuid;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent('X-Correlation-Id', _uuid.v4);
    handler.next(options);
  }
}

/// Agrega el token o el canal, y avisa cuando el backend rechaza el token.
///
/// Nunca envía `tenant_id`: sale del token o del canal (DD, sección 11.3).
class InterceptorAutenticacion extends Interceptor {
  InterceptorAutenticacion({
    required this.obtenerToken,
    required this.canalId,
    required this.alNoAutenticado,
  });

  final String? Function() obtenerToken;
  final String canalId;
  final void Function() alNoAutenticado;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra[extraPublico] == true) {
      options.headers['X-Channel-Id'] = canalId;
    } else {
      final token = obtenerToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final esPublica = err.requestOptions.extra[extraPublico] == true;
    if (err.response?.statusCode == 401 && !esPublica) {
      // TODO(contrato): renovar con POST /v1/auth/refresh cuando OpenAPI
      // defina su cuerpo. Mientras tanto se cierra la sesión.
      alNoAutenticado();
    }
    handler.next(err);
  }
}
