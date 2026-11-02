import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/cliente_api.dart';
import '../domain/perfil.dart';

/// Perfil propio (SCRUM-609 / SCRUM-612). Contrato: `identity.v1.yaml` 1.9.0.
/// La ruta no lleva el usuario ni el tenant: salen del token.
class RepositorioPerfil {
  const RepositorioPerfil(this._dio);

  final Dio _dio;

  /// `GET /v1/users/me`.
  Future<Perfil> obtener() => _llamar(() async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.usuarioActual,
    );
    return Perfil.desdeJson(respuesta.data!);
  });

  /// `PATCH /v1/users/me` con solo los campos que cambiaron. `400` trae los
  /// errores por campo (`fullName`, `phone`).
  Future<Perfil> actualizar(CambiosPerfil cambios) => _llamar(() async {
    final respuesta = await _dio.patch<Map<String, dynamic>>(
      ApiEndpoints.usuarioActual,
      data: cambios.toJson(),
    );
    return Perfil.desdeJson(respuesta.data!);
  });

  Future<T> _llamar<T>(Future<T> Function() llamada) async {
    try {
      return await llamada();
    } on DioException catch (e) {
      throw AppException.desdeDio(e);
    }
  }
}

final repositorioPerfilProvider = Provider<RepositorioPerfil>(
  (ref) => RepositorioPerfil(ref.watch(clienteApiProvider)),
);
