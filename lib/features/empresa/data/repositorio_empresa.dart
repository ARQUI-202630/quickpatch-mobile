import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/invitaciones/invitacion.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/cliente_api.dart';
import '../domain/modelos.dart';

/// Empresa cliente del `empresa_contacto` autenticado y sus usuarios (RF-06,
/// SCRUM-26 / SCRUM-67). Contrato: `identity.v1.yaml` 1.8.0. La empresa sale
/// del token: ninguna ruta lleva su identificador ni el tenant (RN-CC3).
class RepositorioEmpresa {
  const RepositorioEmpresa(this._dio);

  final Dio _dio;

  /// Elementos por página (DD 8.1; el contrato admite hasta 100).
  static const tamanoPagina = 20;

  /// `GET /v1/companies/me`.
  Future<Empresa> empresa() => _llamar(() async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.empresaActual,
    );
    return Empresa.desdeJson(respuesta.data!);
  });

  /// `GET /v1/companies/me/users`, del más antiguo al más reciente.
  Future<PaginaUsuariosEmpresa> usuarios({int pagina = 1}) => _llamar(() async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.usuariosEmpresa,
      queryParameters: {'page': pagina, 'size': tamanoPagina},
    );
    return PaginaUsuariosEmpresa.desdeJson(respuesta.data!);
  });

  /// `POST /v1/companies/me/users`: el usuario queda sin contraseña y la
  /// respuesta trae su invitación.
  Future<UsuarioEmpresaCreado> agregar(DatosUsuarioEmpresa datos) =>
      _llamar(() async {
        final respuesta = await _dio.post<Map<String, dynamic>>(
          ApiEndpoints.usuariosEmpresa,
          data: datos.toJson(),
        );
        return UsuarioEmpresaCreado.desdeJson(respuesta.data!);
      });

  /// `POST .../{userId}/invitation`: enlace nuevo; anula los anteriores.
  /// `409 contrasena-definida` si el usuario ya activó su cuenta.
  Future<Invitacion> nuevaInvitacion(String userId) => _llamar(() async {
    final respuesta = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.invitacionUsuarioEmpresa(userId),
    );
    return Invitacion.desdeJson(respuesta.data!);
  });

  Future<T> _llamar<T>(Future<T> Function() llamada) async {
    try {
      return await llamada();
    } on DioException catch (e) {
      throw AppException.desdeDio(e);
    }
  }
}

final repositorioEmpresaProvider = Provider<RepositorioEmpresa>(
  (ref) => RepositorioEmpresa(ref.watch(clienteApiProvider)),
);

/// Empresa del usuario, para el encabezado de la pantalla de usuarios.
final empresaProvider = FutureProvider.autoDispose<Empresa>(
  (ref) => ref.watch(repositorioEmpresaProvider).empresa(),
);
