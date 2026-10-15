import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/cliente_api.dart';
import '../../../core/network/interceptores.dart';
import '../domain/modelos.dart';

/// Catálogo y solicitudes del cliente. Contratos: `catalog.v1.yaml`
/// (`GET /v1/catalog/categories`) y `service-request.v1.yaml`
/// (`POST /v1/service-requests`, `GET /v1/service-requests/{id}`).
class RepositorioSolicitudes {
  const RepositorioSolicitudes(this._dio);

  final Dio _dio;

  Future<List<Categoria>> categorias() => _llamar(() async {
    final respuesta = await _dio.get<List<dynamic>>(ApiEndpoints.categorias);
    return _aCategorias(respuesta.data!);
  });

  /// Las mismas categorías sin sesión, con `X-Channel-Id`: el tenant sale
  /// del canal (DD 8.1). La usa el registro de técnicos (SCRUM-22, P-03).
  Future<List<Categoria>> categoriasPublicas() => _llamar(() async {
    final respuesta = await _dio.get<List<dynamic>>(
      ApiEndpoints.categorias,
      options: opcionesPublicas(),
    );
    return _aCategorias(respuesta.data!);
  });

  static List<Categoria> _aCategorias(List<dynamic> datos) =>
      datos.cast<Map<String, dynamic>>().map(Categoria.desdeJson).toList();

  Future<Solicitud> crear(NuevaSolicitud datos) => _llamar(() async {
    final respuesta = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.solicitudes,
      data: datos.toJson(),
    );
    return Solicitud.desdeJson(respuesta.data!);
  });

  Future<Solicitud> obtener(String id) => _llamar(() async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.solicitud(id),
    );
    return Solicitud.desdeJson(respuesta.data!);
  });

  Future<T> _llamar<T>(Future<T> Function() llamada) async {
    try {
      return await llamada();
    } on DioException catch (e) {
      throw AppException.desdeDio(e);
    }
  }
}

final repositorioSolicitudesProvider = Provider<RepositorioSolicitudes>(
  (ref) => RepositorioSolicitudes(ref.watch(clienteApiProvider)),
);

/// Categorías activas del tenant del usuario.
final categoriasProvider = FutureProvider.autoDispose<List<Categoria>>(
  (ref) => ref.watch(repositorioSolicitudesProvider).categorias(),
);

/// Categorías activas del tenant del canal, para quien aún no tiene sesión.
final categoriasPublicasProvider = FutureProvider.autoDispose<List<Categoria>>(
  (ref) => ref.watch(repositorioSolicitudesProvider).categoriasPublicas(),
);

/// Detalle de una solicitud.
final solicitudProvider = FutureProvider.autoDispose.family<Solicitud, String>(
  (ref, id) => ref.watch(repositorioSolicitudesProvider).obtener(id),
  retry: reintentarSalvoErrorDelCliente,
);

/// Mientras Riverpod reintenta, el provider sigue en carga. Un 4xx (403, 404)
/// no cambia al reintentar: se muestra de una vez en vez de esperar los
/// reintentos. El resto (sin conexión, 5xx) usa la política por defecto.
Duration? reintentarSalvoErrorDelCliente(int intento, Object error) {
  final status = error is AppException ? error.status : null;
  if (status != null && status >= 400 && status < 500) return null;
  return ProviderContainer.defaultRetry(intento, error);
}
