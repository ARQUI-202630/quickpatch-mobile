import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Aviso de error de un formulario: texto del color de peligro sobre su fondo,
/// con ícono, y anunciado a los lectores de pantalla al aparecer.
class MensajeError extends StatelessWidget {
  const MensajeError(this.mensaje, {super.key});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final estados = context.estados;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: estados.peligroFondo,
          borderRadius: BorderRadius.circular(QpRadio.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(QpEspacio.e3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: estados.peligro,
                size: 20,
              ),
              const SizedBox(width: QpEspacio.e2),
              Expanded(
                child: Text(
                  mensaje,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: estados.peligro),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
