import '../../../core/session/rol_usuario.dart';

/// Perfil del usuario autenticado, según `UserProfile` de
/// `GET /v1/users/me` (identity 1.9.0).
class Perfil {
  const Perfil({
    required this.id,
    required this.email,
    required this.nombreCompleto,
    required this.rol,
    this.telefono,
  });

  factory Perfil.desdeJson(Map<String, dynamic> json) {
    final rol = RolUsuario.desdeValor(json['role'] as String?);
    if (rol == null) {
      throw FormatException('Rol desconocido: ${json['role']}');
    }
    return Perfil(
      id: json['id'] as String,
      email: json['email'] as String,
      nombreCompleto: json['fullName'] as String,
      rol: rol,
      telefono: json['phone'] as String?,
    );
  }

  final String id;
  final String email;
  final String nombreCompleto;
  final RolUsuario rol;
  final String? telefono;
}

/// Cambios del perfil para `PATCH /v1/users/me`. Solo se editan el nombre y
/// el teléfono (SCRUM-609); el correo, el rol, el tenant y el estado de
/// verificación no. El usuario y el tenant salen del token.
class CambiosPerfil {
  const CambiosPerfil({
    this.nombreCompleto,
    this.telefono,
    this.borrarTelefono = false,
  });

  /// Calcula los campos que cambiaron frente a [actual]. Un teléfono vacío lo
  /// borra (`phone: null`).
  factory CambiosPerfil.entre(
    Perfil actual, {
    required String nombreCompleto,
    required String telefono,
  }) {
    final nombre = nombreCompleto.trim();
    final tel = telefono.trim();
    final telActual = actual.telefono ?? '';
    return CambiosPerfil(
      nombreCompleto: nombre == actual.nombreCompleto ? null : nombre,
      telefono: tel.isEmpty || tel == telActual ? null : tel,
      borrarTelefono: tel.isEmpty && telActual.isNotEmpty,
    );
  }

  final String? nombreCompleto;
  final String? telefono;
  final bool borrarTelefono;

  /// El contrato pide al menos un campo (`minProperties: 1`).
  bool get vacio =>
      nombreCompleto == null && telefono == null && !borrarTelefono;

  Map<String, dynamic> toJson() => {
    'fullName': ?nombreCompleto,
    if (telefono != null || borrarTelefono) 'phone': telefono,
  };
}
