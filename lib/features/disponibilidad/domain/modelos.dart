import '../../../core/geo/localidad.dart';

/// Disponibilidad del técnico (`AvailabilityStatus`, DD 5.6). [ocupado] solo
/// lo fija Matching al aceptar una oferta (RN-M6): el técnico no lo elige.
enum EstadoDisponibilidad {
  disponible('disponible', 'Disponible'),
  noDisponible('no_disponible', 'No disponible'),
  ocupado('ocupado', 'Ocupado');

  const EstadoDisponibilidad(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static EstadoDisponibilidad desdeValor(String valor) =>
      values.firstWhere((e) => e.valor == valor);
}

/// Disponibilidad actual del técnico (`Availability`).
class Disponibilidad {
  const Disponibilidad({required this.estado, required this.actualizadaEn});

  factory Disponibilidad.desdeJson(Map<String, dynamic> json) => Disponibilidad(
    estado: EstadoDisponibilidad.desdeValor(json['status'] as String),
    actualizadaEn: DateTime.parse(json['updatedAt'] as String),
  );

  final EstadoDisponibilidad estado;
  final DateTime actualizadaEn;

  /// Mientras atiende un servicio no puede cambiarla (RN-M6).
  bool get puedeCambiar => estado != EstadoDisponibilidad.ocupado;
}

/// Localidades que cubre el técnico (`Coverage`).
class Cobertura {
  const Cobertura(this.localidades);

  factory Cobertura.desdeJson(Map<String, dynamic> json) => Cobertura(
    (json['localities'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Localidad.desdeJson)
        .toList(),
  );

  final List<Localidad> localidades;

  Set<String> get codigos => {for (final l in localidades) l.codigo};
}
