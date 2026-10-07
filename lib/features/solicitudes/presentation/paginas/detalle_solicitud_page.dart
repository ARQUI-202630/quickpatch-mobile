import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../../../core/errors/app_exception.dart';
import '../../data/repositorio_solicitudes.dart';

/// Confirmación y detalle de una solicitud (SCRUM-27). Contrato:
/// `GET /v1/service-requests/{id}`. El estado se actualiza al volver a
/// consultar; el seguimiento en tiempo real llega con las notificaciones.
class DetalleSolicitudPage extends ConsumerWidget {
  const DetalleSolicitudPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitud = ref.watch(solicitudProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu solicitud'),
        leading: IconButton(
          tooltip: 'Inicio',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => context.go(Rutas.inicio),
        ),
      ),
      body: solicitud.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e is AppException ? e.mensaje : 'No pudimos cargar la solicitud.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (s) => RefreshIndicator(
          onRefresh: () => ref.refresh(solicitudProvider(id).future),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                s.estado.etiqueta,
                key: const Key('estado-solicitud'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Descripción'),
                subtitle: Text(s.descripcion),
              ),
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: const Text('Dirección'),
                subtitle: Text(s.direccion),
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Creada'),
                subtitle: Text(_fecha(s.creadaEn.toLocal())),
              ),
              ListTile(
                leading: const Icon(Icons.tag),
                title: const Text('Número de solicitud'),
                subtitle: Text(s.id),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fecha(DateTime f) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(f.day)}/${dos(f.month)}/${f.year} ${dos(f.hour)}:${dos(f.minute)}';
  }
}
