/// Tipo de cuenta que se crea desde la app (RF-01 y RF-06).
///
/// El registro de técnicos y proveedores (RF-02) necesita las categorías de
/// Catalog Service para elegir la especialidad; se agrega cuando ese servicio
/// publique `GET /v1/service-categories`.
enum TipoCuenta { hogar, empresa }

/// Datos del formulario de registro. Los nombres de los campos del contrato
/// están en [toJson].
class DatosRegistro {
  const DatosRegistro({
    required this.tipo,
    required this.nombreCompleto,
    required this.email,
    required this.password,
    this.telefono,
    this.razonSocial,
    this.nit,
  });

  final TipoCuenta tipo;
  final String nombreCompleto;
  final String email;
  final String password;
  final String? telefono;

  /// Solo para [TipoCuenta.empresa].
  final String? razonSocial;
  final String? nit;

  Map<String, dynamic> toJson() => {
    'fullName': nombreCompleto.trim(),
    'email': email.trim(),
    'password': password,
    if (_conTexto(telefono)) 'phone': telefono!.trim(),
    if (tipo == TipoCuenta.empresa) ...{
      'legalName': razonSocial?.trim(),
      'nit': nit?.trim(),
    },
  };

  static bool _conTexto(String? v) => v != null && v.trim().isNotEmpty;
}
