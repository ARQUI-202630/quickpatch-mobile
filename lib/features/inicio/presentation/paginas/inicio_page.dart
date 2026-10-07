import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../autenticacion/presentation/controlador_sesion.dart';
import '../../domain/opciones_por_rol.dart';

/// Pantalla de inicio según el rol del usuario autenticado.
class InicioPage extends ConsumerWidget {
  const InicioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(controladorSesionProvider).value;
    if (sesion == null) return const SizedBox.shrink();
    final usuario = sesion.usuario;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${usuario.fullName}'),
        actions: [
          IconButton(
            key: const Key('boton-salir'),
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(controladorSesionProvider.notifier).cerrarSesion(),
          ),
        ],
      ),
      body: usuario.rol.usaAppMovil
          ? ListView(
              children: [
                for (final opcion in opcionesPara(usuario.rol))
                  ListTile(
                    title: Text(opcion.titulo),
                    subtitle: Text('Próximamente · ${opcion.requisito}'),
                    enabled: false,
                  ),
              ],
            )
          : const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'La administración se hace desde el panel web de QUICKPATCH.',
                key: Key('mensaje-admin'),
              ),
            ),
    );
  }
}
