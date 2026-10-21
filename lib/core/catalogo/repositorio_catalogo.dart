import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_exception.dart';
import '../network/api_endpoints.dart';
import '../network/cliente_api.dart';
import '../network/interceptores.dart';
import 'categoria.dart';

/// Categorías del tenant (`GET /v1/service-requests/categories`,
/// service-request 1.8.0): ServiceRequest las sirve desde su réplica de Catalog
/// (ADR-025). Lo usan las solicitudes, el registro de técnicos y el equipo del
/// proveedor.
class RepositorioCatalogo {
  const RepositorioCatalogo(this._dio);

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

  Future<T> _llamar<T>(Future<T> Function() llamada) async {
    try {
      return await llamada();
    } on DioException catch (e) {
      throw AppException.desdeDio(e);
    }
  }
}

final repositorioCatalogoProvider = Provider<RepositorioCatalogo>(
  (ref) => RepositorioCatalogo(ref.watch(clienteApiProvider)),
);

/// Categorías activas del tenant del usuario.
final categoriasProvider = FutureProvider.autoDispose<List<Categoria>>(
  (ref) => ref.watch(repositorioCatalogoProvider).categorias(),
);

/// Categorías activas del tenant del canal, para quien aún no tiene sesión.
final categoriasPublicasProvider = FutureProvider.autoDispose<List<Categoria>>(
  (ref) => ref.watch(repositorioCatalogoProvider).categoriasPublicas(),
);
