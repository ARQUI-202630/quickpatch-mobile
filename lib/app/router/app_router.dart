import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/sesion.dart';
import '../../features/autenticacion/presentation/controlador_sesion.dart';
import '../../features/autenticacion/presentation/paginas/inicio_sesion_page.dart';
import '../../features/autenticacion/presentation/paginas/registro_page.dart';
import '../../features/inicio/presentation/paginas/inicio_page.dart';
import '../../shared/widgets/vista_cargando.dart';
import 'rutas.dart';

/// Decide a dónde redirigir según el estado de la sesión.
String? calcularRedireccion(AsyncValue<Sesion?> sesion, String ubicacion) {
  if (sesion.isLoading && !sesion.hasValue) {
    return ubicacion == Rutas.cargando ? null : Rutas.cargando;
  }
  final autenticado = sesion.value != null;
  final publica =
      ubicacion == Rutas.iniciarSesion || ubicacion == Rutas.registro;
  final enEntrada = publica || ubicacion == Rutas.cargando;
  if (!autenticado) {
    return publica ? null : Rutas.iniciarSesion;
  }
  return enEntrada ? Rutas.inicio : null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresco = ValueNotifier<int>(0);
  ref.listen(controladorSesionProvider, (_, _) => refresco.value++);

  final router = GoRouter(
    initialLocation: Rutas.cargando,
    refreshListenable: refresco,
    redirect: (context, state) => calcularRedireccion(
      ref.read(controladorSesionProvider),
      state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: Rutas.cargando,
        builder: (context, state) => const VistaCargando(),
      ),
      GoRoute(
        path: Rutas.iniciarSesion,
        builder: (context, state) => const InicioSesionPage(),
      ),
      GoRoute(
        path: Rutas.registro,
        builder: (context, state) => const RegistroPage(),
      ),
      GoRoute(
        path: Rutas.inicio,
        builder: (context, state) => const InicioPage(),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresco.dispose();
  });
  return router;
});
