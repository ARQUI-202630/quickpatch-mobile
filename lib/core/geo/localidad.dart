/// Localidad de Bogotá D.C. (`Locality`, service-request.v1.yaml 1.8.0).
class Localidad {
  const Localidad({required this.codigo, required this.nombre});

  factory Localidad.desdeJson(Map<String, dynamic> json) =>
      Localidad(codigo: json['code'] as String, nombre: json['name'] as String);

  /// Código oficial, por ejemplo `02` para Chapinero.
  final String codigo;
  final String nombre;
}
