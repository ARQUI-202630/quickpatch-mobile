import '../../../core/invitaciones/invitacion.dart';

/// Empresa cliente del usuario (`Company`, identity.v1.yaml 1.8.0, DD 5.19).
class Empresa {
  const Empresa({
    required this.id,
    required this.razonSocial,
    required this.nit,
    required this.correoContacto,
    this.telefonoContacto,
  });

  factory Empresa.desdeJson(Map<String, dynamic> json) => Empresa(
    id: json['id'] as String,
    razonSocial: json['legalName'] as String,
    nit: json['nit'] as String,
    correoContacto: json['contactEmail'] as String,
    telefonoContacto: json['contactPhone'] as String?,
  );

  final String id;
  final String razonSocial;
  final String nit;
  final String correoContacto;
  final String? telefonoContacto;
}

/// Usuario de la empresa (`CompanyUser`). [contrasenaDefinida] es falso
/// mientras no haya usado su invitación.
class UsuarioEmpresa {
  const UsuarioEmpresa({
    required this.userId,
    required this.email,
    required this.nombre,
    required this.contrasenaDefinida,
    this.telefono,
  });

  factory UsuarioEmpresa.desdeJson(Map<String, dynamic> json) => UsuarioEmpresa(
    userId: json['userId'] as String,
    email: json['email'] as String,
    nombre: json['fullName'] as String,
    telefono: json['phone'] as String?,
    contrasenaDefinida: json['passwordDefined'] as bool,
  );

  final String userId;
  final String email;
  final String nombre;
  final String? telefono;
  final bool contrasenaDefinida;
}

/// Página de `GET /v1/companies/me/users`, del más antiguo al más reciente.
class PaginaUsuariosEmpresa {
  const PaginaUsuariosEmpresa({
    required this.usuarios,
    required this.pagina,
    required this.total,
  });

  factory PaginaUsuariosEmpresa.desdeJson(Map<String, dynamic> json) =>
      PaginaUsuariosEmpresa(
        usuarios: (json['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(UsuarioEmpresa.desdeJson)
            .toList(),
        pagina: json['page'] as int,
        total: json['totalItems'] as int,
      );

  final List<UsuarioEmpresa> usuarios;
  final int pagina;
  final int total;
}

/// Datos del alta (`CompanyUserRequest`): sin contraseña, porque el usuario
/// la define con su invitación (RN-CC4), y sin empresa ni tenant, que salen
/// del token (RN-CC3).
class DatosUsuarioEmpresa {
  const DatosUsuarioEmpresa({
    required this.nombreCompleto,
    required this.email,
    this.telefono,
  });

  final String nombreCompleto;
  final String email;
  final String? telefono;

  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'fullName': nombreCompleto.trim(),
    if (telefono != null && telefono!.trim().isNotEmpty)
      'phone': telefono!.trim(),
  };
}

/// Usuario recién agregado con su invitación (`CompanyUserCreated`).
class UsuarioEmpresaCreado {
  const UsuarioEmpresaCreado({required this.nombre, required this.invitacion});

  factory UsuarioEmpresaCreado.desdeJson(Map<String, dynamic> json) =>
      UsuarioEmpresaCreado(
        nombre: json['fullName'] as String,
        invitacion: Invitacion.desdeJson(
          json['invitation'] as Map<String, dynamic>,
        ),
      );

  final String nombre;
  final Invitacion invitacion;
}
