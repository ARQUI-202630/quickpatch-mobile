import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'almacen_sesion.dart';
import 'sesion.dart';

/// Estado de la sesión: `null` si no hay usuario autenticado.
///
/// El router escucha este estado para decidir entre el inicio de sesión y
/// el inicio de cada rol. El login y el registro viven en
/// `features/autenticacion` (`AccionesSesion`) y le entregan la sesión con
/// [iniciar].
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

  /// Guarda la sesión que entregó Identity y la publica.
  Future<void> iniciar(Sesion sesion) async {
    await ref.read(almacenSesionProvider).guardar(sesion);
    state = AsyncData(sesion);
  }

  /// Cambia el nombre del usuario de la sesión después de editar el perfil
  /// (SCRUM-612), para que se vea sin volver a iniciar sesión.
  Future<void> actualizarNombre(String nombreCompleto) async {
    final actual = state.value;
    if (actual == null) return;
    final sesion = actual.copyWith(
      usuario: actual.usuario.copyWith(fullName: nombreCompleto),
    );
    await ref.read(almacenSesionProvider).guardar(sesion);
    state = AsyncData(sesion);
  }

  Future<void> cerrarSesion() async {
    await ref.read(almacenSesionProvider).borrar();
    state = const AsyncData(null);
  }
}

final controladorSesionProvider =
    AsyncNotifierProvider<ControladorSesion, Sesion?>(ControladorSesion.new);
