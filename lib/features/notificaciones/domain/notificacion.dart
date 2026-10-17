/// Notificación del buzón (`Notification`, communication.v1.yaml 1.0.0).
/// Communication arma el título y el mensaje en español, sin dirección ni
/// teléfono (RN-SR13).
class Notificacion {
  const Notificacion({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.creadaEn,
    this.serviceRequestId,
    this.leidaEn,
  });

  factory Notificacion.desdeJson(Map<String, dynamic> json) => Notificacion(
    id: json['id'] as String,
    tipo: json['type'] as String,
    titulo: json['title'] as String,
    mensaje: json['message'] as String,
    serviceRequestId: json['serviceRequestId'] as String?,
    creadaEn: DateTime.parse(json['createdAt'] as String),
    leidaEn: json['readAt'] == null
        ? null
        : DateTime.parse(json['readAt'] as String),
  );

  final String id;

  /// `NotificationType`. Se guarda como texto: los tipos nuevos que la app
  /// no conoce se muestran igual (agregar un tipo es un cambio compatible).
  final String tipo;
  final String titulo;
  final String mensaje;

  /// Solicitud relacionada; `null` en los tipos de registro y verificación.
  final String? serviceRequestId;
  final DateTime creadaEn;
  final DateTime? leidaEn;

  bool get leida => leidaEn != null;

  Notificacion marcadaLeida(DateTime cuando) => Notificacion(
    id: id,
    tipo: tipo,
    titulo: titulo,
    mensaje: mensaje,
    serviceRequestId: serviceRequestId,
    creadaEn: creadaEn,
    leidaEn: leidaEn ?? cuando,
  );
}

/// Página de `GET /v1/notifications` (`NotificationPage`).
class PaginaNotificaciones {
  const PaginaNotificaciones({
    required this.notificaciones,
    required this.pagina,
    required this.total,
    required this.sinLeer,
  });

  factory PaginaNotificaciones.desdeJson(Map<String, dynamic> json) =>
      PaginaNotificaciones(
        notificaciones: (json['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(Notificacion.desdeJson)
            .toList(),
        pagina: json['page'] as int,
        total: json['totalItems'] as int,
        sinLeer: json['unreadCount'] as int,
      );

  final List<Notificacion> notificaciones;
  final int pagina;
  final int total;

  /// Todas las sin leer del usuario, sin importar la página.
  final int sinLeer;
}
