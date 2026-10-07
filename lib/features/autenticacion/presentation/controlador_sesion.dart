import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/almacen_sesion.dart';
import '../../../core/session/sesion.dart';
import '../data/repositorio_autenticacion_impl.dart';
import '../domain/datos_registro.dart';

/// Estado de la sesión: `null` si no hay usuario autenticado.
///
/// El router escucha este estado para decidir entre el inicio de sesión y
/// el inicio de cada rol.
class ControladorSesion extends AsyncNotifier<Sesion?> {
  @override
  Future<Sesion?> build() async {
    final almacen = ref.read(almacenSesionProvider);
    final sesion = await almacen.cargar();
    if (sesion != null && sesion.estaVencida(DateTime.now())) {
      // Sin renovación definida en el contrato, una sesión vencida obliga a
      // volver a iniciar sesión.
      await almacen.borrar();
      return null;
    }
    return sesion;
  }

  /// Inicia sesión y la guarda. Lanza `AppException` para que la pantalla
  /// muestre el error; el estado solo cambia si el inicio es exitoso.
  Future<void> iniciarSesion({
    required String email,
    required String password,
  }) async {
    final sesion = await ref
        .read(repositorioAutenticacionProvider)
        .iniciarSesion(email: email, password: password);
    await ref.read(almacenSesionProvider).guardar(sesion);
    state = AsyncData(sesion);
  }

  /// Crea la cuenta y entra con ella, para llegar directo al inicio.
  Future<void> registrarEIniciarSesion(DatosRegistro datos) async {
    await ref.read(repositorioAutenticacionProvider).registrar(datos);
    await iniciarSesion(email: datos.email, password: datos.password);
  }

  Future<void> cerrarSesion() async {
    await ref.read(almacenSesionProvider).borrar();
    state = const AsyncData(null);
  }
}

final controladorSesionProvider =
    AsyncNotifierProvider<ControladorSesion, Sesion?>(ControladorSesion.new);
