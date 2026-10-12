import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';
import 'vista_estado.dart';

/// Error al cargar datos: título, el mensaje del código de error si viene de
/// la API y "Reintentar". Unifica el estado de error de todas las pantallas.
class VistaError extends StatelessWidget {
  const VistaError({
    required this.error,
    required this.titulo,
    this.alReintentar,
    super.key,
  });

  final Object error;
  final String titulo;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) => VistaEstado(
    icono: Icons.cloud_off_rounded,
    tono: Theme.of(context).colorScheme.error,
    titulo: titulo,
    mensaje: error is AppException ? (error as AppException).mensaje : null,
    accion: alReintentar == null ? null : 'Reintentar',
    alAccionar: alReintentar,
  );
}

/// Indicador de carga con su etiqueta para lectores de pantalla.
class IndicadorCarga extends StatelessWidget {
  const IndicadorCarga({this.etiqueta = 'Cargando', super.key});

  final String etiqueta;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: CircularProgressIndicator(semanticsLabel: etiqueta),
    ),
  );
}
