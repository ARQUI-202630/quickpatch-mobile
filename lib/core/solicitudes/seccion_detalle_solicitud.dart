import 'package:flutter/widgets.dart';

import 'estado_solicitud.dart';
import 'resumen_calificacion.dart';

/// Lo que el detalle de la solicitud del cliente entrega a las secciones que
/// agregan otras features (el pago y la calificación).
class DatosSeccionSolicitud {
  const DatosSeccionSolicitud({
    required this.solicitudId,
    required this.estado,
    required this.soloLectura,
    this.calificacion,
  });

  final String solicitudId;
  final EstadoSolicitud estado;

  /// Solicitud de la empresa que ve otro usuario (RN-SR14): sin las acciones
  /// de quien la creó.
  final bool soloLectura;
  final ResumenCalificacion? calificacion;
}

/// Sección que otra feature agrega al detalle; `null` si no aplica en ese
/// estado. Las arma `app/router` y el detalle las recibe por parámetro: la
/// feature `solicitudes` no importa a `pagos` ni a `calificacion`
/// (features/README.md, SCRUM-714).
typedef SeccionDetalleSolicitud = Widget? Function(
  DatosSeccionSolicitud datos,
  VoidCallback alCambiar,
);
