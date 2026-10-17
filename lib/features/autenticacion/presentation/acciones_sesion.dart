import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/controlador_sesion.dart';
import '../data/repositorio_autenticacion_impl.dart';
import '../domain/datos_registro.dart';

/// Inicio de sesión y registro contra Identity. Si salen bien, entregan la
/// sesión a `core/session` ([ControladorSesion.iniciar]); si fallan, lanzan
/// `AppException` para que la pantalla muestre el error y el estado de la
/// sesión no cambia.
class AccionesSesion {
  const AccionesSesion(this._ref);

  final Ref _ref;

  Future<void> iniciarSesion({
    required String email,
    required String password,
  }) async {
    final sesion = await _ref
        .read(repositorioAutenticacionProvider)
        .iniciarSesion(email: email, password: password);
    await _ref.read(controladorSesionProvider.notifier).iniciar(sesion);
  }

  /// Crea la cuenta y entra con ella, para llegar directo al inicio.
  Future<void> registrarEIniciarSesion(DatosRegistro datos) async {
    await _ref.read(repositorioAutenticacionProvider).registrar(datos);
    await iniciarSesion(email: datos.email, password: datos.password);
  }

  /// Registra al técnico o proveedor y entra con su cuenta: el inicio le
  /// muestra que está en verificación (`verificationStatus` de la sesión).
  Future<void> registrarTecnicoEIniciarSesion(
    DatosRegistroTecnico datos,
  ) async {
    await _ref.read(repositorioAutenticacionProvider).registrarTecnico(datos);
    await iniciarSesion(email: datos.email, password: datos.password);
  }
}

final accionesSesionProvider = Provider<AccionesSesion>(AccionesSesion.new);
