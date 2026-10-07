import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/cliente_api.dart';
import '../domain/modelos.dart';

/// Catálogo y solicitudes del cliente. Contratos: `catalog.v1.yaml`
/// (`GET /v1/catalog/categories`) y `service-request.v1.yaml`
/// (`POST /v1/service-requests`, `GET /v1/service-requests/{id}`).
class RepositorioSolicitudes {
  const RepositorioSolicitudes(this._dio);

  final Dio _dio;

  Future<List<Categoria>> categorias() => _llamar(() async {
    final respuesta = await _dio.get<List<dynamic>>(ApiEndpoints.categorias);
    return respuesta.data!
        .cast<Map<String, dynamic>>()
        .map(Categoria.desdeJson)
        .toList();
  });

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

/// Detalle de una solicitud.
final solicitudProvider = FutureProvider.autoDispose.family<Solicitud, String>(
  (ref, id) => ref.watch(repositorioSolicitudesProvider).obtener(id),
);
