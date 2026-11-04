/// Invitación de un solo uso para que alguien defina su contraseña
/// (esquema `Invitation`, identity.v1.yaml 1.7.0). La usan el equipo del
/// proveedor (SCRUM-98) y los usuarios de una empresa cliente (SCRUM-67).
/// Identity solo guarda el hash: el enlace se ve una sola vez.
class Invitacion {
  const Invitacion({required this.enlace, required this.venceEn});

  factory Invitacion.desdeJson(Map<String, dynamic> json) => Invitacion(
    enlace: json['link'] as String,
    venceEn: DateTime.parse(json['expiresAt'] as String),
  );

  final String enlace;
  final DateTime venceEn;
}
