/// Mensaje del canal en tiempo real `/v1/realtime` (DD, sección 8.5).
///
/// El mensaje solo avisa del cambio: la app vuelve a pedir el detalle con
/// `GET /v1/service-requests/{id}`. Si el WebSocket se cae, la app consulta
/// el detalle cada [intervaloRespaldo] hasta reconectar (RNF-06).
///
/// TODO(contrato): la conexión se implementa cuando el contrato defina el
/// formato de la primera trama con el token.
class MensajeTiempoReal {
  const MensajeTiempoReal({
    required this.tipo,
    required this.serviceRequestId,
    required this.status,
    required this.ocurridoEn,
  });

  factory MensajeTiempoReal.fromJson(Map<String, dynamic> json) =>
      MensajeTiempoReal(
        tipo: json['type'] as String,
        serviceRequestId: json['serviceRequestId'] as String?,
        status: json['status'] as String?,
        ocurridoEn: DateTime.parse(json['occurredAt'] as String),
      );

  static const intervaloRespaldo = Duration(seconds: 30);

  final String tipo;
  final String? serviceRequestId;
  final String? status;
  final DateTime ocurridoEn;
}
