import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../domain/modelos.dart';
import '../estado_vista.dart';

/// Insignia con el estado de una solicitud: ícono y etiqueta en el tono del
/// estado (texto 700 sobre fondo 50, ≥ 4.5:1 en ambos temas).
class ChipEstado extends StatelessWidget {
  const ChipEstado(this.estado, {super.key});

  final EstadoSolicitud estado;

  @override
  Widget build(BuildContext context) {
    final vista = vistaDe(estado);
    final (color, fondo) = vista.colores(context.estados);
    return Semantics(
      label: 'Estado: ${estado.etiqueta}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(QpRadio.pildora),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: QpEspacio.e3,
            vertical: QpEspacio.e1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(vista.icono, size: 16, color: color),
              const SizedBox(width: QpEspacio.e1),
              Flexible(
                child: Text(
                  estado.etiqueta,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
