import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/cliente_api.dart';
import '../domain/modelos.dart';

/// Equipo del proveedor autenticado (RF-16, SCRUM-36 / SCRUM-98). Contrato:
/// `identity.v1.yaml` 1.7.0. El proveedor sale del token: ninguna ruta lleva
/// su identificador ni el tenant (RN-U3, RN-TP4).
class RepositorioEquipo {
  const RepositorioEquipo(this._dio);

  final Dio _dio;

  /// Elementos por página (DD 8.1; el contrato admite hasta 100).
  static const tamanoPagina = 20;

  /// `GET /v1/providers/me/technicians`, del más antiguo al más reciente.
  Future<PaginaEquipo> listar(FiltroEquipo filtro, {int pagina = 1}) =>
      _llamar(() async {
        final respuesta = await _dio.get<Map<String, dynamic>>(
          ApiEndpoints.equipoProveedor,
          queryParameters: {
            'status': ?filtro.valor,
            'page': pagina,
            'size': tamanoPagina,
          },
        );
        return PaginaEquipo.desdeJson(respuesta.data!);
      });

  /// `POST /v1/providers/me/technicians`: el técnico queda pendiente de
  /// verificación y sin contraseña; la respuesta trae su invitación.
  Future<TecnicoCreado> darDeAlta(DatosAltaTecnico datos) => _llamar(() async {
    final respuesta = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.equipoProveedor,
      data: datos.toJson(),
    );
    return TecnicoCreado.desdeJson(respuesta.data!);
  });

  /// `POST .../{userId}/invitation`: enlace nuevo; anula los anteriores.
  /// `409 contrasena-definida` si el técnico ya activó su cuenta.
  Future<Invitacion> nuevaInvitacion(String userId) => _llamar(() async {
    final respuesta = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.invitacionTecnico(userId),
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

final repositorioEquipoProvider = Provider<RepositorioEquipo>(
  (ref) => RepositorioEquipo(ref.watch(clienteApiProvider)),
);
