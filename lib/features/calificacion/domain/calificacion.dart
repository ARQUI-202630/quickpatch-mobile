/// Calificación registrada (`RatingResponse`, service-request 1.10.0).
class Calificacion {
  const Calificacion({
    required this.solicitudId,
    required this.puntaje,
    required this.calificadaEn,
    this.comentario,
  });

  factory Calificacion.desdeJson(Map<String, dynamic> json) => Calificacion(
    solicitudId: json['serviceRequestId'] as String,
    puntaje: json['score'] as int,
    comentario: json['comment'] as String?,
    calificadaEn: DateTime.parse(json['ratedAt'] as String),
  );

  final String solicitudId;
  final int puntaje;
  final String? comentario;
  final DateTime calificadaEn;
}
