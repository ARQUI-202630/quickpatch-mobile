import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/cliente_api.dart';
import 'autenticacion_api.dart';

/// Activación de la cuenta de un técnico del equipo de un proveedor
/// (SCRUM-98): define su contraseña con la invitación. No inicia sesión;
/// después el técnico entra con su correo y la contraseña nueva.
class RepositorioActivacion {
  const RepositorioActivacion(this._api);

  final AutenticacionApi _api;

  /// Lanza `AppException`: `400 enlace-invalido` si el token no sirve
  /// (usado, vencido o anulado) o `400 validacion` con `errors.password`.
  Future<void> definirContrasena({
    required String token,
    required String password,
  }) async {
    try {
      await _api.definirContrasena(token, password);
    } on DioException catch (e) {
      throw AppException.desdeDio(e);
    }
  }
}

final repositorioActivacionProvider = Provider<RepositorioActivacion>(
  (ref) =>
      RepositorioActivacion(AutenticacionApi(ref.watch(clienteApiProvider))),
);
