import '../../../core/session/sesion.dart';
import 'datos_registro.dart';

/// Operaciones de autenticación que necesita la app.
abstract interface class RepositorioAutenticacion {
  /// `POST /v1/auth/login`. Lanza `AppException` si falla.
  Future<Sesion> iniciarSesion({
    required String email,
    required String password,
  });

  /// Registra un cliente hogar o una empresa cliente. Lanza `AppException`.
  Future<void> registrar(DatosRegistro datos);
}
