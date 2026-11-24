// Lo usan el detalle de la solicitud (que la lee del contrato) y la calificación del cliente; SCRUM-714.

/// Calificación que trae el detalle de la solicitud (`rating`, service-request
/// 1.12.0): puntaje de 1 a 5, comentario opcional y cuándo se calificó.
class ResumenCalificacion {
  const ResumenCalificacion({
    required this.puntaje,
    required this.calificadaEn,
    this.comentario,
  });

  factory ResumenCalificacion.desdeJson(Map<String, dynamic> json) =>
      ResumenCalificacion(
        puntaje: json['score'] as int,
        comentario: json['comment'] as String?,
        calificadaEn: DateTime.parse(json['ratedAt'] as String),
      );

  final int puntaje;
  final String? comentario;
  final DateTime calificadaEn;
}
