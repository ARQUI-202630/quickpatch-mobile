import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/notificaciones/contador_notificaciones.dart';
import '../../../../core/session/controlador_sesion.dart';
import '../../../../core/session/rol_usuario.dart';
import '../../../../shared/widgets/botones.dart';

/// Pestaña de cuenta: datos de la sesión, buzón de notificaciones
/// (SCRUM-459), licencias y cierre de sesión (SCRUM-441).
class CuentaPage extends ConsumerWidget {
  const CuentaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(controladorSesionProvider).value?.usuario;
    if (usuario == null) return const SizedBox.shrink();
    final esquema = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    final sinLeer = tieneBuzon(usuario.rol)
        ? ref.watch(contadorNotificacionesProvider).value ?? 0
        : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta')),
      body: ListView(
        padding: const EdgeInsets.all(QpEspacio.pantalla),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(QpEspacio.e5),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: esquema.primaryContainer,
                    foregroundColor: esquema.onPrimaryContainer,
                    child: Text(
                      iniciales(usuario.fullName),
                      style: texto.titleMedium?.copyWith(
                        color: esquema.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: QpEspacio.e4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(usuario.fullName, style: texto.titleMedium),
                        const SizedBox(height: QpEspacio.e1),
                        Text(
                          etiquetaRol(usuario.rol),
                          key: const Key('cuenta-rol'),
                          style: texto.bodyMedium?.copyWith(
                            color: esquema.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Buzón (SCRUM-459); el proveedor no tiene (403).
          if (tieneBuzon(usuario.rol)) ...[
            const SizedBox(height: QpEspacio.e4),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                key: const Key('fila-notificaciones'),
                leading: const Icon(Icons.notifications_none_rounded),
                title: const Text('Notificaciones'),
                subtitle: switch (sinLeer) {
                  0 => null,
                  1 => const Text('1 sin leer'),
                  _ => Text('$sinLeer sin leer'),
                },
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(Rutas.notificaciones),
              ),
            ),
          ],
          const SizedBox(height: QpEspacio.e4),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Licencias de software'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'QUICKPATCH',
              ),
            ),
          ),
          const SizedBox(height: QpEspacio.e8),
          BotonPeligro(
            key: const Key('boton-salir'),
            texto: 'Cerrar sesión',
            icono: Icons.logout_rounded,
            alPresionar: () =>
                ref.read(controladorSesionProvider.notifier).cerrarSesion(),
          ),
        ],
      ),
    );
  }
}

/// Hasta dos iniciales del nombre, en mayúscula.
String iniciales(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  return partes.take(2).map((p) => p[0].toUpperCase()).join();
}

String etiquetaRol(RolUsuario rol) => switch (rol) {
  RolUsuario.cliente => 'Cliente',
  RolUsuario.empresaContacto => 'Contacto de empresa',
  RolUsuario.tecnico => 'Técnico',
  RolUsuario.proveedor => 'Proveedor',
  RolUsuario.adminTenant => 'Administrador',
  RolUsuario.adminPlataforma => 'Administrador de la plataforma',
};
