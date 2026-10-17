import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/controlador_sesion.dart';
import '../../core/session/rol_usuario.dart';
import '../../features/equipo/presentation/paginas/equipo_page.dart';
import '../../features/solicitudes/presentation/paginas/servicios_tecnico_page.dart';
import '../../shared/widgets/vista_estado.dart';
import '../router/rutas.dart';
import 'navegacion_por_rol.dart';

/// Pestaña del medio: el trabajo propio de cada rol (SCRUM-441). Está en el
/// shell porque compone pantallas de varias features.
///
/// El proveedor ve su equipo (RF-16, SCRUM-98) y el técnico sus servicios
/// asignados (RF-17, SCRUM-92); las ofertas (RF-10, SCRUM-80) se sumarán
/// ahí. Los contratos publicados todavía no tienen el listado de solicitudes
/// del cliente (RF-11): la pestaña lo dice en vez de mostrar datos fijos.
class ActividadPage extends ConsumerWidget {
  const ActividadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rol = ref.watch(controladorSesionProvider).value?.usuario.rol;
    if (rol == null) return const SizedBox.shrink();
    if (rol == RolUsuario.proveedor) return const EquipoPage();
    if (rol == RolUsuario.tecnico) return const ServiciosTecnicoPage();
    final destinos = destinosPara(rol);
    final titulo = destinos.isEmpty ? 'Actividad' : destinos[1].etiqueta;
    final puedeSolicitar = rol == RolUsuario.cliente;

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Center(
        child: SingleChildScrollView(
          child: VistaEstado(
            key: const Key('actividad-proximamente'),
            icono: Icons.receipt_long_outlined,
            titulo: 'Próximamente',
            mensaje: 'Aquí verás el historial y el estado de tus solicitudes (RF-11).',
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
