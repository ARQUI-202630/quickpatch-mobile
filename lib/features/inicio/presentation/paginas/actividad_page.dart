import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../../../core/session/rol_usuario.dart';
import '../../../../shared/widgets/vista_estado.dart';
import '../../../autenticacion/presentation/controlador_sesion.dart';
import '../../domain/navegacion_por_rol.dart';

/// Pestaña del medio: el trabajo propio de cada rol (SCRUM-441).
///
/// Los contratos publicados todavía no tienen el listado de solicitudes del
/// cliente (RF-11), las ofertas del técnico (RF-10, SCRUM-30) ni el equipo
/// del proveedor (RF-16): la pestaña lo dice en vez de mostrar datos fijos.
class ActividadPage extends ConsumerWidget {
  const ActividadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rol = ref.watch(controladorSesionProvider).value?.usuario.rol;
    if (rol == null) return const SizedBox.shrink();
    final destinos = destinosPara(rol);
    final titulo = destinos.isEmpty ? 'Actividad' : destinos[1].etiqueta;

    final (icono, mensaje) = switch (rol) {
      RolUsuario.tecnico => (
        Icons.work_outline_rounded,
        'Aquí llegarán las ofertas de servicio que te asigne QUICKPATCH '
            '(RF-10).',
      ),
      RolUsuario.proveedor => (
        Icons.groups_outlined,
        'Aquí podrás gestionar los técnicos de tu equipo (RF-16).',
      ),
      _ => (
        Icons.receipt_long_outlined,
        'Aquí verás el historial y el estado de tus solicitudes (RF-11).',
      ),
    };
    final puedeSolicitar = rol == RolUsuario.cliente;

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Center(
        child: SingleChildScrollView(
          child: VistaEstado(
            key: const Key('actividad-proximamente'),
            icono: icono,
            titulo: 'Próximamente',
            mensaje: mensaje,
            accion: puedeSolicitar ? 'Crear una solicitud' : null,
            alAccionar: puedeSolicitar
                ? () => context.push(Rutas.nuevaSolicitud)
                : null,
          ),
        ),
      ),
    );
  }
}
