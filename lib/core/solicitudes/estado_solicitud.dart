// Vocabulario de la solicitud que comparten varias features (solicitudes, pagos, calificación); SCRUM-714.

/// Estado de la solicitud (`ServiceRequestStatus`, DD 7.4).
enum EstadoSolicitud {
  buscandoTecnico('buscando_tecnico', 'Buscando técnico'),
  enEspera('en_espera', 'En espera'),
  asignado('asignado', 'Técnico asignado'),
  cotizado('cotizado', 'Cotizada'),
  cotizacionAceptada('cotizacion_aceptada', 'Cotización aceptada'),
  enProgreso('en_progreso', 'En progreso'),
  completado('completado', 'Completada'),
  pagado('pagado', 'Pagada'),
  cancelado('cancelado', 'Cancelada');

  const EstadoSolicitud(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static EstadoSolicitud desdeValor(String valor) =>
      values.firstWhere((e) => e.valor == valor);

  /// Estados anteriores al inicio del servicio, desde los que se puede
  /// cancelar (RN-SR7; service-request 1.5.0).
  bool get cancelable => switch (this) {
    buscandoTecnico ||
    enEspera ||
    asignado ||
    cotizado ||
    cotizacionAceptada => true,
    enProgreso || completado || pagado || cancelado => false,
  };
}
