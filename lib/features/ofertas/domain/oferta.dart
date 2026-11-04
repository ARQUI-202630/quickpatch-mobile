import '../../../core/geo/localidad.dart';

/// Oferta de servicio dirigida al técnico (`Offer`, matching.v1.yaml 1.0.0).
///
/// No trae la dirección ni el cliente: solo los recibe el técnico asignado
/// (RN-SR13). Vence a los 3 minutos de ofrecida (RN-M8).
class Oferta {
  const Oferta({
    required this.attemptId,
    required this.serviceRequestId,
    required this.categoriaId,
    required this.descripcion,
    required this.localidad,
    required this.distanciaMetros,
    required this.ofrecidaEn,
    required this.venceEn,
    this.categoriaNombre,
  });

  factory Oferta.desdeJson(Map<String, dynamic> json) => Oferta(
    attemptId: json['attemptId'] as String,
    serviceRequestId: json['serviceRequestId'] as String,
    categoriaId: json['categoryId'] as String,
    categoriaNombre: json['categoryName'] as String?,
    descripcion: json['description'] as String,
    localidad: Localidad.desdeJson(json['locality'] as Map<String, dynamic>),
    distanciaMetros: (json['distanceMeters'] as num).toDouble(),
    ofrecidaEn: DateTime.parse(json['offeredAt'] as String),
    venceEn: DateTime.parse(json['expiresAt'] as String),
  );

  final String attemptId;
  final String serviceRequestId;
  final String categoriaId;

  /// `null` mientras Matching no tenga la réplica del catálogo.
  final String? categoriaNombre;
  final String descripcion;
  final Localidad localidad;
  final double distanciaMetros;
  final DateTime ofrecidaEn;
  final DateTime venceEn;

  /// Tiempo que le queda para responder; cero si ya venció.
  Duration restante(DateTime ahora) {
    final falta = venceEn.difference(ahora);
    return falta.isNegative ? Duration.zero : falta;
  }
}
