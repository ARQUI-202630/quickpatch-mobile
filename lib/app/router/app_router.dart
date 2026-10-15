import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/sesion.dart';
import '../../features/autenticacion/domain/enlace_invitacion.dart';
import '../../features/autenticacion/presentation/controlador_sesion.dart';
import '../../features/autenticacion/presentation/paginas/activar_cuenta_page.dart';
import '../../features/autenticacion/presentation/paginas/inicio_sesion_page.dart';
import '../../features/autenticacion/presentation/paginas/registro_page.dart';
import '../../features/autenticacion/presentation/paginas/registro_tecnico_page.dart';
import '../../features/disponibilidad/presentation/paginas/disponibilidad_page.dart';
import '../../features/equipo/presentation/paginas/alta_tecnico_page.dart';
import '../../features/inicio/presentation/paginas/cuenta_page.dart';
import '../../features/solicitudes/presentation/paginas/detalle_solicitud_page.dart';
import '../../features/solicitudes/presentation/paginas/nueva_solicitud_page.dart';
import '../../features/solicitudes/presentation/paginas/solicitud_asignada_page.dart';
import '../../shared/widgets/vista_cargando.dart';
import '../shell/actividad_page.dart';
import '../shell/estructura_principal.dart';
import '../shell/inicio_page.dart';
import 'rutas.dart';

/// Decide a dónde redirigir según el estado de la sesión.
String? calcularRedireccion(AsyncValue<Sesion?> sesion, String ubicacion) {
  // El enlace de invitación puede abrir la app en frío, mientras la sesión
  // carga: se atiende siempre, con o sin sesión, para no perder el token.
  if (ubicacion == Rutas.activarCuenta) return null;
  if (sesion.isLoading && !sesion.hasValue) {
    return ubicacion == Rutas.cargando ? null : Rutas.cargando;
  }
  final autenticado = sesion.value != null;
  final publica =
      ubicacion == Rutas.iniciarSesion ||
      ubicacion == Rutas.registro ||
      ubicacion == Rutas.registroTecnico;
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
        path: Rutas.registroTecnico,
        builder: (context, state) => const RegistroTecnicoPage(),
      ),
      GoRoute(
        path: Rutas.activarCuenta,
        builder: (context, state) =>
            ActivarCuentaPage(token: tokenDeInvitacion(state.uri.toString())),
      ),
      // Pestañas con la barra inferior; sin transición al cambiar de una a
      // otra, como una barra de navegación nativa.
      ShellRoute(
        builder: (context, state, child) =>
            EstructuraPrincipal(ubicacion: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: Rutas.inicio,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: InicioPage()),
          ),
          GoRoute(
            path: Rutas.actividad,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ActividadPage()),
          ),
          GoRoute(
            path: Rutas.cuenta,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CuentaPage()),
          ),
        ],
      ),
      GoRoute(
        path: Rutas.disponibilidad,
        builder: (context, state) => const DisponibilidadPage(),
      ),
      GoRoute(
        path: Rutas.altaTecnico,
        builder: (context, state) => const AltaTecnicoPage(),
      ),
      GoRoute(
        path: Rutas.nuevaSolicitud,
        builder: (context, state) => NuevaSolicitudPage(
          categoriaInicial: state.uri.queryParameters['categoria'],
        ),
      ),
      GoRoute(
        path: Rutas.solicitudAsignadaPatron,
        builder: (context, state) =>
            SolicitudAsignadaPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Rutas.detalleSolicitudPatron,
        builder: (context, state) =>
            DetalleSolicitudPage(id: state.pathParameters['id']!),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresco.dispose();
  });
  return router;
});
