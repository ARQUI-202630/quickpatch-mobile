/// Mensaje del canal en tiempo real `/v1/realtime` (`realtime.v1.yaml`,
/// ADR-023, DD 8.5).
///
/// El mensaje solo avisa del cambio: la app vuelve a pedir el detalle por REST
/// (`GET /v1/service-requests/{id}`), que es la fuente de verdad. Los avisos
/// pueden llegar repetidos o en desorden. Si el WebSocket se cae, la app
/// consulta el detalle cada [intervaloRespaldo] hasta reconectar (RNF-06).
class MensajeTiempoReal {
  const MensajeTiempoReal({
    required this.tipo,
    this.serviceRequestId,
    this.status,
    this.attemptId,
    this.ocurridoEn,
    this.expiraEn,
    this.mensajeChat,
  });

  /// Lee una trama del servidor. Devuelve `null` si no trae `type`.
  static MensajeTiempoReal? desdeJson(Map<String, dynamic> json) {
    final tipo = json['type'];
    if (tipo is! String) return null;
    return MensajeTiempoReal(
      tipo: tipo,
      serviceRequestId: json['serviceRequestId'] as String?,
      status: json['status'] as String?,
      attemptId: json['attemptId'] as String?,
      ocurridoEn: _fecha(json['occurredAt']),
      expiraEn: _fecha(json['expiresAt']),
      mensajeChat: json['message'] is Map<String, dynamic>
          ? json['message'] as Map<String, dynamic>
          : null,
    );
  }

  /// Igual que [desdeJson], para el formato completo del contrato.
  factory MensajeTiempoReal.fromJson(Map<String, dynamic> json) =>
      desdeJson(json)!;

  static DateTime? _fecha(Object? valor) =>
      valor is String ? DateTime.parse(valor) : null;

  static const intervaloRespaldo = Duration(seconds: 30);

  /// Tipos de aviso del contrato 1.1.0. Los demás se ignoran.
  static const autenticacionAceptada = 'auth.accepted';
  static const cambioDeEstado = 'service-request.status-changed';
  static const ofertaCreada = 'offer.created';
  static const conteosCambiaron = 'service-request.counts-changed';

  /// Mensaje nuevo en el chat de una solicitud (1.1.0, ADR-026). A diferencia
  /// de los demás avisos, trae el mensaje completo: la conversación lo agrega
  /// sin volver a pedir el historial.
  static const mensajeDeChat = 'chat.message';

  final String tipo;
  final String? serviceRequestId;
  final String? status;
  final String? attemptId;
  final DateTime? ocurridoEn;

  /// Solo en `auth.accepted`: vencimiento del token.
  final DateTime? expiraEn;

  /// Solo en `chat.message`: el `ChatMessage` de `communication.v1.yaml`.
  final Map<String, dynamic>? mensajeChat;

  /// Si avisa un cambio de estado de la solicitud [id].
  bool cambiaSolicitud(String id) =>
      tipo == cambioDeEstado && serviceRequestId == id;

  /// Si trae un mensaje nuevo del chat de la solicitud [id].
  bool esChatDe(String id) =>
      tipo == mensajeDeChat && serviceRequestId == id && mensajeChat != null;
}
