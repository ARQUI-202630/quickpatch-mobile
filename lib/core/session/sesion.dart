import 'rol_usuario.dart';

/// Usuario autenticado, según `user` (`UserProfile`) en la respuesta de
/// `POST /v1/auth/login` (contrato `identity.v1.yaml`).
class UsuarioSesion {
  const UsuarioSesion({
    required this.userId,
    required this.fullName,
    required this.rol,
    this.companyId,
    this.verificationStatus,
  });

  factory UsuarioSesion.fromJson(Map<String, dynamic> json) {
    final rol = RolUsuario.desdeValor(json['role'] as String?);
    if (rol == null) {
      throw FormatException('Rol desconocido: ${json['role']}');
    }
    return UsuarioSesion(
      userId: (json['id'] ?? json['userId']) as String,
      fullName: json['fullName'] as String,
      rol: rol,
      companyId: json['companyId'] as String?,
      verificationStatus: json['verificationStatus'] as String?,
    );
  }

  final String userId;
  final String fullName;
  final RolUsuario rol;

  /// Solo para `empresa_contacto` (pendiente del registro de empresa).
  final String? companyId;

  /// Solo para `tecnico` y `proveedor`: `pendiente`, `aprobado`, etc.
  final String? verificationStatus;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'fullName': fullName,
    'role': rol.valor,
    'companyId': companyId,
    'verificationStatus': verificationStatus,
  };
}

/// Tokens y usuario de la sesión actual.
///
/// El tenant no se guarda ni se envía: lo lleva el token y lo propaga el
/// API Gateway (DD, sección 11.3).
class Sesion {
  const Sesion({
    required this.accessToken,
    this.refreshToken,
    required this.expiraEn,
    required this.usuario,
  });

  /// Construye la sesión a partir de la respuesta del login.
  factory Sesion.desdeLogin(Map<String, dynamic> json, DateTime ahora) {
    final segundos = (json['expiresIn'] ?? json['accessTokenExpiresIn']) as int;
    return Sesion(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      expiraEn: ahora.toUtc().add(Duration(seconds: segundos)),
      usuario: UsuarioSesion.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  /// Formato con el que la sesión se guarda en el almacenamiento seguro.
  factory Sesion.fromJson(Map<String, dynamic> json) => Sesion(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String?,
    expiraEn: DateTime.parse(json['expiraEn'] as String),
    usuario: UsuarioSesion.fromJson(json['usuario'] as Map<String, dynamic>),
  );

  final String accessToken;

  /// Nulo mientras Identity no emita refresh tokens (DD 3.1, pendiente).
  final String? refreshToken;
  final DateTime expiraEn;
  final UsuarioSesion usuario;

  bool estaVencida(DateTime ahora) => !ahora.toUtc().isBefore(expiraEn);

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiraEn': expiraEn.toIso8601String(),
    'usuario': usuario.toJson(),
  };
}
