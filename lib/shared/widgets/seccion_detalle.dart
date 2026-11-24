import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Tarjeta con título de una sección del detalle de la solicitud: cotización,
/// pago, calificación (SCRUM-714).
class SeccionDetalle extends StatelessWidget {
  const SeccionDetalle({required this.titulo, required this.child, super.key});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(QpEspacio.e4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(titulo, style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: QpEspacio.e3),
          child,
        ],
      ),
    ),
  );
}
