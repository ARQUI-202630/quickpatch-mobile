import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../data/repositorio_solicitudes.dart';
import '../../domain/modelos.dart';
import 'cotizacion_tecnico.dart' show SeccionCotizacion;
import 'galeria_evidencias.dart';

/// Fotos del trabajo que ve el cliente (RF-15, SCRUM-95; service-request
/// 1.7.0): desde que el técnico inicia el servicio hasta después del pago.
class EvidenciaCliente extends ConsumerWidget {
  const EvidenciaCliente({required this.solicitud, super.key});

  final Solicitud solicitud;

  static bool aplica(EstadoSolicitud estado) =>
      estado == EstadoSolicitud.enProgreso ||
      estado == EstadoSolicitud.completado ||
      estado == EstadoSolicitud.pagado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!aplica(solicitud.estado)) return const SizedBox.shrink();
    final fotos = ref.watch(evidenciasProvider(solicitud.id));
    final secundario = Theme.of(context).colorScheme.onSurfaceVariant;
    return SeccionCotizacion(
      key: const Key('evidencia-cliente'),
      titulo: 'Fotos del trabajo',
      child: fotos.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Column(
          key: const Key('error-evidencias'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No pudimos cargar las fotos.'),
            TextButton(
              onPressed: () => ref.invalidate(evidenciasProvider(solicitud.id)),
              child: const Text('Reintentar'),
            ),
          ],
        ),
        data: (lista) => lista.isEmpty
            ? Text(
                'Tu técnico subirá fotos del trabajo antes de completarlo.',
                key: const Key('sin-fotos'),
                style: TextStyle(color: secundario),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GaleriaEvidencias(
                    solicitudId: solicitud.id,
                    evidencias: lista,
                  ),
                  const SizedBox(height: QpEspacio.e2),
                  Text(
                    'Tócalas para verlas completas.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: secundario),
                  ),
                ],
              ),
      ),
    );
  }
}
