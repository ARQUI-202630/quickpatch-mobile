import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/interceptores.dart';

/// Llamadas REST de Identity Service usadas en la autenticación.
class AutenticacionApi {
  const AutenticacionApi(this._dio);

  final Dio _dio;

  /// DD, sección 8.3.2.
  Future<Map<String, dynamic>> iniciarSesion(
    String email,
    String password,
  ) async {
    final respuesta = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      data: {'email': email, 'password': password},
      options: opcionesPublicas(),
    );
    return respuesta.data!;
  }

  /// `POST /v1/auth/register/client` (openapi/identity.v1.yaml).
  Future<void> registrarCliente(Map<String, dynamic> datos) => _dio.post<void>(
    ApiEndpoints.registroCliente,
    data: datos,
    options: opcionesPublicas(),
  );

  /// `POST /v1/auth/register/company` (openapi/identity.v1.yaml).
  Future<void> registrarEmpresa(Map<String, dynamic> datos) => _dio.post<void>(
    ApiEndpoints.registroEmpresa,
    data: datos,
    options: opcionesPublicas(),
  );
}
