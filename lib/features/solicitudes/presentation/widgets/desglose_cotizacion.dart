import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/utils/fechas.dart';
import '../../domain/modelos.dart';

/// Mano de obra, materiales, total y vencimiento de una cotización (RF-34).
/// Lo comparten el técnico y el cliente.
class DesgloseCotizacion extends StatelessWidget {
  const DesgloseCotizacion(this.cotizacion, {super.key});

  final Cotizacion cotizacion;

  @override
  Widget build(BuildContext context) {
    final c = cotizacion;
    final texto = Theme.of(context).textTheme;
    final secundario = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LineaMonto('Mano de obra', c.manoDeObra.formatear()),
        LineaMonto('Materiales', c.materiales.formatear()),
        const Divider(height: QpEspacio.e4),
        LineaMonto(
          'Total',
          c.total.formatear(),
          clave: Key('total-cotizacion-${c.numero}'),
          destacada: true,
        ),
        if (c.detalle != null) ...[
          const SizedBox(height: QpEspacio.e3),
          Text(c.detalle!, key: Key('detalle-cotizacion-${c.numero}')),
        ],
        const SizedBox(height: QpEspacio.e3),
        Text(
          switch (c.estado) {
            EstadoCotizacion.pendiente =>
              'Vence el ${fechaCorta(c.venceEn.toLocal())}',
            _ when c.respondidaEn != null =>
              '${c.estado.etiqueta} el '
                  '${fechaCorta(c.respondidaEn!.toLocal())}',
            _ => 'Enviada el ${fechaCorta(c.creadaEn.toLocal())}',
          },
          key: Key('vencimiento-cotizacion-${c.numero}'),
          style: texto.bodySmall?.copyWith(color: secundario),
        ),
        if (c.motivoRechazo != null) ...[
          const SizedBox(height: QpEspacio.e1),
          Text(
            'Motivo: ${c.motivoRechazo}',
            key: Key('motivo-rechazo-${c.numero}'),
            style: texto.bodySmall?.copyWith(color: secundario),
          ),
        ],
      ],
    );
  }
}

/// Concepto a la izquierda y valor a la derecha; con texto grande, el valor
/// pasa debajo para no desbordar.
class LineaMonto extends StatelessWidget {
  const LineaMonto(
    this.concepto,
    this.valor, {
    this.clave,
    this.destacada = false,
    super.key,
  });

  final String concepto;
  final String valor;
  final Key? clave;
  final bool destacada;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final estilo = destacada
        ? texto.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : texto.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: QpEspacio.e1),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: QpEspacio.e3,
        children: [
          Text(concepto, style: estilo),
          Text(valor, key: clave, style: estilo),
        ],
      ),
    );
  }
}
