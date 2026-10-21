import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/controlador_sesion.dart';
import '../../core/session/rol_usuario.dart';
import '../../features/equipo/presentation/paginas/equipo_page.dart';
import '../../features/ofertas/data/repositorio_ofertas.dart';
import '../../features/ofertas/presentation/widgets/oferta_pendiente.dart';
import '../../features/solicitudes/presentation/paginas/mis_solicitudes_page.dart';
import '../../features/solicitudes/presentation/paginas/servicios_tecnico_page.dart';
import '../../shared/widgets/vista_estado.dart';
import 'navegacion_por_rol.dart';

/// Pestaña del medio: el trabajo propio de cada rol (SCRUM-441). Está en el
/// shell porque compone pantallas de varias features.
///
/// El proveedor ve su equipo (RF-16, SCRUM-98) y el técnico sus servicios
/// asignados (RF-17, SCRUM-467) con su oferta pendiente arriba (RF-10,
/// SCRUM-80). El cliente ve sus solicitudes y el `empresa_contacto` las de su
/// empresa (RF-11, service-request 1.9.0).
class ActividadPage extends ConsumerWidget {
  const ActividadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rol = ref.watch(controladorSesionProvider).value?.usuario.rol;
    if (rol == null) return const SizedBox.shrink();
    if (rol == RolUsuario.proveedor) return const EquipoPage();
    if (rol == RolUsuario.tecnico) {
      return ServiciosTecnicoPage(
        encabezado: const OfertaPendiente(),
        alRecargar: () => ref.invalidate(ofertaPendienteProvider),
      );
    }
    if (rol == RolUsuario.cliente || rol == RolUsuario.empresaContacto) {
      return const MisSolicitudesPage();
    }
    final destinos = destinosPara(rol);
    final titulo = destinos.isEmpty ? 'Actividad' : destinos[1].etiqueta;
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: const Center(
        child: SingleChildScrollView(
          child: VistaEstado(
            key: Key('actividad-proximamente'),
            icono: Icons.receipt_long_outlined,
            titulo: 'Sin actividad',
            mensaje: 'Este rol no tiene actividad en la app.',
          ),
        ),
      ),
    );
  }
}
