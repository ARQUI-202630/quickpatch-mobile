import 'package:flutter/material.dart';

/// Acción secundaria (por ejemplo, "Ver detalle"): contorno del tema.
class BotonSecundario extends StatelessWidget {
  const BotonSecundario({
    required this.texto,
    required this.alPresionar,
    this.icono,
    super.key,
  });

  final String texto;
  final VoidCallback? alPresionar;
  final IconData? icono;

  @override
  Widget build(BuildContext context) => icono == null
      ? OutlinedButton(onPressed: alPresionar, child: Text(texto))
      : OutlinedButton.icon(
          onPressed: alPresionar,
          icon: Icon(icono),
          label: Text(texto),
        );
}

/// Acción destructiva o de rechazo (por ejemplo, "Rechazar" una oferta o
/// "Cerrar sesión"): contorno y texto del color de error.
class BotonPeligro extends StatelessWidget {
  const BotonPeligro({
    required this.texto,
    required this.alPresionar,
    this.icono,
    super.key,
  });

  final String texto;
  final VoidCallback? alPresionar;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final estilo = OutlinedButton.styleFrom(
      foregroundColor: error,
      side: BorderSide(color: error),
    );
    return icono == null
        ? OutlinedButton(
            style: estilo,
            onPressed: alPresionar,
            child: Text(texto),
          )
        : OutlinedButton.icon(
            style: estilo,
            onPressed: alPresionar,
            icon: Icon(icono),
            label: Text(texto),
          );
  }
}
