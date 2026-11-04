import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Estado vacío, de error o "próximamente" de una pantalla o sección: un
/// ícono, un título, una explicación opcional y una acción opcional.
class VistaEstado extends StatelessWidget {
  const VistaEstado({
    required this.icono,
    required this.titulo,
    this.mensaje,
    this.accion,
    this.alAccionar,
    this.tono,
    super.key,
  });

  final IconData icono;
  final String titulo;
  final String? mensaje;

  /// Texto del botón; se muestra solo con [alAccionar].
  final String? accion;
  final VoidCallback? alAccionar;

  /// Color del ícono y su fondo; por omisión, el primario.
  final Color? tono;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    final color = tono ?? esquema.primary;

    return Padding(
      padding: const EdgeInsets.all(QpEspacio.e6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(QpEspacio.e4),
              child: Icon(icono, size: 32, color: color),
            ),
          ),
          const SizedBox(height: QpEspacio.e4),
          Text(titulo, style: texto.titleMedium, textAlign: TextAlign.center),
          if (mensaje != null) ...[
            const SizedBox(height: QpEspacio.e2),
            Text(
              mensaje!,
              style: texto.bodyMedium?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (accion != null && alAccionar != null) ...[
            const SizedBox(height: QpEspacio.e5),
            OutlinedButton(onPressed: alAccionar, child: Text(accion!)),
          ],
        ],
      ),
    );
  }
}
