import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/interceptores.dart';
import '../../../core/seguridad/cifrado_contrasena.dart';

/// Llamadas REST de Identity Service usadas en la autenticación. Desde
/// identity 1.11.0 la contraseña viaja cifrada en `encryptedPassword`, nunca
/// en `password`.
class AutenticacionApi {
  const AutenticacionApi(this._dio, this._cifrado);

  final Dio _dio;
  final CifradoContrasena _cifrado;

  /// Cambia `password` por `encryptedPassword` en el cuerpo (o en `user`, en
  /// el registro de empresa).
  Future<void> _conContrasenaCifrada(String ruta, Map<String, dynamic> datos) {
    final usuario = datos['user'];
    final destino = usuario is Map<String, dynamic> ? usuario : datos;
    final password = destino['password'] as String;
    return _cifrado.enviar(password, (cifrada) {
      final copia = Map<String, dynamic>.of(datos);
      final cuerpo = identical(destino, datos)
          ? copia
          : (copia['user'] = Map<String, dynamic>.of(destino));
      cuerpo
        ..remove('password')
        ..['encryptedPassword'] = cifrada;
      return _dio.post<void>(ruta, data: copia, options: opcionesPublicas());
    });
  }

  /// DD, sección 8.3.2.
  Future<Map<String, dynamic>> iniciarSesion(
    String email,
    String password,
  ) async {
    final respuesta = await _cifrado.enviar(
      password,
      (cifrada) => _dio.post<Map<String, dynamic>>(
        ApiEndpoints.login,
        data: {'email': email, 'encryptedPassword': cifrada},
        options: opcionesPublicas(),
      ),
    );
    return respuesta.data!;
  }

  /// `POST /v1/auth/register/client` (openapi/identity.v1.yaml).
  Future<void> registrarCliente(Map<String, dynamic> datos) =>
      _conContrasenaCifrada(ApiEndpoints.registroCliente, datos);

  /// `POST /v1/auth/register/technician` (openapi/identity.v1.yaml).
  Future<void> registrarTecnico(Map<String, dynamic> datos) =>
      _conContrasenaCifrada(ApiEndpoints.registroTecnico, datos);

  /// `POST /v1/auth/password/setup` (identity 1.7.0): el técnico del equipo
  /// de un proveedor define su contraseña con el token de su invitación. Sin
  /// token de sesión; el tenant sale del canal (RN-U5). Responde 204.
  Future<void> definirContrasena(String token, String password) =>
      _cifrado.enviar(
        password,
        (cifrada) => _dio.post<void>(
          ApiEndpoints.definirContrasena,
          data: {'token': token, 'encryptedPassword': cifrada},
          options: opcionesPublicas(),
        ),
      );

  /// `POST /v1/auth/password-recovery` (identity 1.10.0): pide la
  /// recuperación de la contraseña. Sin token de sesión; el tenant sale del
  /// canal (RN-U5). Responde 202 exista o no la cuenta.
  Future<void> pedirRecuperacion(String email) => _dio.post<void>(
    ApiEndpoints.recuperarContrasena,
    data: {'email': email},
    options: opcionesPublicas(),
  );

  /// `POST /v1/auth/register/company` (openapi/identity.v1.yaml).
  Future<void> registrarEmpresa(Map<String, dynamic> datos) =>
      _conContrasenaCifrada(ApiEndpoints.registroEmpresa, datos);
}
