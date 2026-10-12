/// Tipo de cuenta de cliente que se crea desde la app (RF-01 y RF-06).
/// El registro de técnicos y proveedores (RF-02) usa [DatosRegistroTecnico].
enum TipoCuenta { hogar, empresa }

/// Rol con el que se registra quien ofrece servicios (RF-02). [valor] es el
/// del contrato (`RegisterTechnicianRequest.role`).
enum RolProfesional {
  tecnico('tecnico'),
  proveedor('proveedor');

  const RolProfesional(this.valor);

  final String valor;
}

/// Datos del registro de técnico o proveedor
/// (`POST /v1/auth/register/technician`, identity.v1.yaml). El tenant no se
/// envía: sale del canal (RN-U5). La cuenta queda pendiente de verificación.
class DatosRegistroTecnico {
  const DatosRegistroTecnico({
    required this.rol,
    required this.nombreCompleto,
    required this.email,
    required this.password,
    required this.telefono,
    required this.documento,
    required this.especialidadId,
  });

  final RolProfesional rol;
  final String nombreCompleto;
  final String email;
  final String password;
  final String telefono;
  final String documento;

  /// Categoría de Catalog que atiende.
  final String especialidadId;

  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password,
    'fullName': nombreCompleto.trim(),
    'phone': telefono.trim(),
    'documentId': documento.trim(),
    'specialtyId': especialidadId,
    'role': rol.valor,
  };
}

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
