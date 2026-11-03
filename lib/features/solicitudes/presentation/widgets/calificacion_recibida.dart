import 'package:flutter/material.dart';

/// Calificación que el cliente le dio al técnico (RF-12, service-request
/// 1.10.0): de una a cinco estrellas, o «Sin calificar» si [puntaje] es `null`.
class CalificacionRecibida extends StatelessWidget {
  const CalificacionRecibida(this.puntaje, {super.key});

  final int? puntaje;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final puntaje = this.puntaje;
    if (puntaje == null) {
      return Text(
        'Sin calificar',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: esquema.onSurfaceVariant),
      );
    }
    return Semantics(
      label: 'Calificación: $puntaje de 5',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              i <= puntaje ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 20,
              color: esquema.primary,
            ),
        ],
      ),
    );
  }
}
