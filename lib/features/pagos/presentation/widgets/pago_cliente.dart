import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/codigo_error.dart';
import '../../../solicitudes/domain/modelos.dart';
import '../../../solicitudes/presentation/widgets/cotizacion_tecnico.dart'
    show SeccionCotizacion;
import '../../data/repositorio_pagos.dart';
import '../../domain/pago.dart';

/// Pago que ve el cliente en el detalle (RF-22, SCRUM-116; payments 1.0.0):
/// desde que el técnico completa el servicio. Muestra el total y el botón de
/// pagar; tras un rechazo, el motivo y el reintento; mientras la pasarela no
/// responde, que se está confirmando; y al final, el pago aprobado.
class PagoCliente extends ConsumerWidget {
  const PagoCliente({
    required this.solicitud,
    required this.alCambiar,
    super.key,
  });

  final Solicitud solicitud;

  /// Vuelve a pedir la solicitud y el pago.
  final VoidCallback alCambiar;

  static bool aplica(EstadoSolicitud estado) =>
      estado == EstadoSolicitud.completado || estado == EstadoSolicitud.pagado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!aplica(solicitud.estado)) return const SizedBox.shrink();
    return SeccionCotizacion(
      key: const Key('pago-cliente'),
      titulo: 'Pago',
      child: ref
          .watch(pagoProvider(solicitud.id))
          .when(
            skipLoadingOnRefresh: true,
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _SinPago(
              noListo:
                  e is AppException && e.codigo == CodigoError.paymentNotReady,
              alReintentar: alCambiar,
            ),
            data: (pago) => _Contenido(pago: pago, alCambiar: alCambiar),
          ),
    );
  }
}

class _SinPago extends StatelessWidget {
  const _SinPago({required this.noListo, required this.alReintentar});

  final bool noListo;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) => Column(
    key: Key(noListo ? 'pago-no-listo' : 'error-pago'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        noListo
            ? 'Estamos preparando tu pago. Estará listo en unos segundos.'
            : 'No pudimos cargar el pago.',
      ),
      TextButton(onPressed: alReintentar, child: const Text('Actualizar')),
    ],
  );
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.pago, required this.alCambiar});

  final Pago pago;
  final VoidCallback alCambiar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final estados = context.estados;
    final total = Row(
      children: [
        Expanded(child: Text('Total', style: tema.textTheme.bodyLarge)),
        Text(
          pago.monto.formatear(),
          key: const Key('total-pago'),
          style: tema.textTheme.titleLarge,
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        total,
        const SizedBox(height: QpEspacio.e3),
        switch (pago.estado) {
          EstadoPago.aprobado => _Aviso(
            key: const Key('pago-aprobado'),
            icono: Icons.check_circle_rounded,
            color: estados.exito,
            fondo: estados.exitoFondo,
            texto: 'Pago aprobado. Tu comprobante quedó emitido.',
          ),
          EstadoPago.procesando => Column(
            key: const Key('pago-procesando'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Aviso(
                icono: Icons.hourglass_top_rounded,
                color: estados.aviso,
                fondo: estados.avisoFondo,
                texto:
                    'Estamos confirmando tu pago con la pasarela. No pagues '
                    'de nuevo; esto toma menos de un minuto.',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: alCambiar,
                  child: const Text('Actualizar'),
                ),
              ),
            ],
          ),
          EstadoPago.pendiente || EstadoPago.rechazado => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pago.estado == EstadoPago.rechazado) ...[
                _Aviso(
                  key: const Key('pago-rechazado'),
                  icono: Icons.error_outline_rounded,
                  color: estados.peligro,
                  fondo: estados.peligroFondo,
                  texto: '${pago.motivoLegible} Puedes intentar de nuevo.',
                ),
                const SizedBox(height: QpEspacio.e3),
              ],
              FilledButton.icon(
                key: const Key('boton-pagar'),
                onPressed: () async {
                  final pagado = await context.push<bool>(
                    Rutas.pagarSolicitud(pago.solicitudId),
                  );
                  if (pagado ?? false) alCambiar();
                },
                icon: const Icon(Icons.lock_rounded),
                label: Text(
                  pago.estado == EstadoPago.rechazado
                      ? 'Intentar de nuevo'
                      : 'Pagar ${pago.monto.formatear()}',
                ),
              ),
            ],
          ),
        },
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.icono,
    required this.color,
    required this.fondo,
    required this.texto,
    super.key,
  });

  final IconData icono;
  final Color color;
  final Color fondo;
  final String texto;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(QpRadio.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(QpEspacio.e3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color, size: 20),
            const SizedBox(width: QpEspacio.e2),
            Expanded(
              child: Text(
                texto,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
