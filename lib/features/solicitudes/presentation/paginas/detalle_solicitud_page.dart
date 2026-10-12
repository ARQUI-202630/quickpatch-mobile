import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../shared/widgets/vista_estado.dart';
import '../../data/repositorio_solicitudes.dart';
import '../../domain/modelos.dart';
import '../estado_vista.dart';

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
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Cargando'),
        ),
        error: (e, _) => Center(
          child: SingleChildScrollView(
            child: VistaEstado(
              key: const Key('detalle-error'),
              icono: Icons.cloud_off_rounded,
              tono: Theme.of(context).colorScheme.error,
              titulo: 'No pudimos cargar la solicitud',
              mensaje: e is AppException ? e.mensaje : null,
              accion: 'Reintentar',
              alAccionar: () => ref.invalidate(solicitudProvider(id)),
            ),
          ),
        ),
        data: (s) => RefreshIndicator(
          onRefresh: () => ref.refresh(solicitudProvider(id).future),
          child: ListView(
            padding: const EdgeInsets.all(QpEspacio.pantalla),
            children: [
              _EncabezadoEstado(s.estado),
              const SizedBox(height: QpEspacio.e5),
              _Datos(s),
              const SizedBox(height: QpEspacio.e4),
              Text(
                'Desliza hacia abajo para actualizar el estado.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EncabezadoEstado extends StatelessWidget {
  const _EncabezadoEstado(this.estado);

  final EstadoSolicitud estado;

  @override
  Widget build(BuildContext context) {
    final vista = vistaDe(estado);
    final (color, fondo) = vista.colores(context.estados);
    final texto = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(QpEspacio.e5),
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(QpEspacio.e4),
                child: Icon(vista.icono, size: 36, color: color),
              ),
            ),
            const SizedBox(height: QpEspacio.e4),
            Text(
              estado.etiqueta,
              key: const Key('estado-solicitud'),
              textAlign: TextAlign.center,
              style: texto.headlineSmall,
            ),
            const SizedBox(height: QpEspacio.e2),
            Text(
              vista.descripcion,
              textAlign: TextAlign.center,
              style: texto.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Datos extends StatelessWidget {
  const _Datos(this.solicitud);

  final Solicitud solicitud;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        _Fila(Icons.description_outlined, 'Descripción', solicitud.descripcion),
        _Fila(Icons.place_outlined, 'Dirección', solicitud.direccion),
        _Fila(
          Icons.schedule_rounded,
          'Creada',
          fechaCorta(solicitud.creadaEn.toLocal()),
        ),
        _Fila(Icons.tag_rounded, 'Número de solicitud', solicitud.id),
      ],
    ),
  );
}

class _Fila extends StatelessWidget {
  const _Fila(this.icono, this.titulo, this.valor);

  final IconData icono;
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icono),
    title: Text(titulo),
    subtitle: Text(valor),
  );
}

/// Fecha como `dd/mm/aaaa hh:mm`.
String fechaCorta(DateTime f) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(f.day)}/${dos(f.month)}/${f.year} ${dos(f.hour)}:${dos(f.minute)}';
}
