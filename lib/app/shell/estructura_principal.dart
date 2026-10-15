import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/rol_usuario.dart';
import '../../features/autenticacion/presentation/controlador_sesion.dart';
import '../../features/inicio/domain/navegacion_por_rol.dart';
import '../../features/solicitudes/presentation/widgets/escucha_asignaciones.dart';

/// Envuelve las pestañas principales con la barra de navegación inferior,
/// cuyas pestañas dependen del rol de la sesión (SCRUM-441).
class EstructuraPrincipal extends ConsumerWidget {
  const EstructuraPrincipal({
    required this.ubicacion,
    required this.child,
    super.key,
  });

  final String ubicacion;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rol = ref.watch(controladorSesionProvider).value?.usuario.rol;
    final destinos = rol == null
        ? const <DestinoPrincipal>[]
        : destinosPara(rol);
    if (destinos.isEmpty) return child;

    return Scaffold(
      // El técnico recibe el aviso de las solicitudes que le asignan (SCRUM-92).
      body: rol == RolUsuario.tecnico
          ? EscuchaAsignaciones(child: child)
          : child,
      bottomNavigationBar: NavigationBar(
        key: const Key('barra-navegacion'),
        selectedIndex: indiceDestino(destinos, ubicacion) ?? 0,
        onDestinationSelected: (i) => context.go(destinos[i].ruta),
        destinations: [
          for (final destino in destinos)
            NavigationDestination(
              icon: Icon(destino.icono),
              selectedIcon: Icon(destino.iconoActivo),
              label: destino.etiqueta,
            ),
        ],
      ),
    );
  }
}
