import 'package:flutter/material.dart';

/// Botón principal de un formulario. Mientras [cargando], se deshabilita y
/// muestra un indicador del tamaño del texto, para que el botón no salte.
class BotonPrincipal extends StatelessWidget {
  const BotonPrincipal({
    required this.texto,
    required this.alPresionar,
    this.cargando = false,
    this.icono,
    super.key,
  });

  final String texto;
  final VoidCallback alPresionar;
  final bool cargando;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final contenido = cargando
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.onPrimary,
              semanticsLabel: 'Enviando',
            ),
          )
        : Text(texto);
    final accion = cargando ? null : alPresionar;
    return icono == null || cargando
        ? FilledButton(onPressed: accion, child: contenido)
        : FilledButton.icon(
            onPressed: accion,
            icon: Icon(icono),
            label: contenido,
          );
  }
}
