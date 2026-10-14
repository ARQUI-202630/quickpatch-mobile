/// Estado de verificación del técnico (`VerificationStatus`, DD 5.3).
enum EstadoVerificacion {
  pendiente('pendiente', 'Pendiente'),
  aprobado('aprobado', 'Aprobado'),
  rechazado('rechazado', 'Rechazado'),
  suspendido('suspendido', 'Suspendido');

  const EstadoVerificacion(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static EstadoVerificacion desdeValor(String valor) =>
      values.firstWhere((e) => e.valor == valor);
}

/// Filtro del equipo (`status` de `GET /v1/providers/me/technicians`):
/// `activo` son los aprobados; `inactivo`, los demás.
enum FiltroEquipo {
  todos(null, 'Todos'),
  activos('activo', 'Activos'),
  inactivos('inactivo', 'Inactivos');

  const FiltroEquipo(this.valor, this.etiqueta);

  /// Valor del parámetro `status`; `null` no lo envía.
  final String? valor;
  final String etiqueta;
}

/// Técnico del equipo del proveedor (`ProviderTechnician`).
class TecnicoEquipo {
  const TecnicoEquipo({
    required this.userId,
    required this.nombre,
    required this.especialidadId,
    required this.verificacion,
  });

  factory TecnicoEquipo.desdeJson(Map<String, dynamic> json) => TecnicoEquipo(
    userId: json['userId'] as String,
    nombre: json['fullName'] as String,
    especialidadId: json['specialtyId'] as String,
    verificacion: EstadoVerificacion.desdeValor(
      json['verificationStatus'] as String,
    ),
  );

  final String userId;
  final String nombre;
  final String especialidadId;
  final EstadoVerificacion verificacion;
}

/// Página del equipo (`ProviderTechnicianPage`).
class PaginaEquipo {
  const PaginaEquipo({
    required this.tecnicos,
    required this.pagina,
    required this.total,
  });

  factory PaginaEquipo.desdeJson(Map<String, dynamic> json) => PaginaEquipo(
    tecnicos: (json['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(TecnicoEquipo.desdeJson)
        .toList(),
    pagina: json['page'] as int,
    total: json['totalItems'] as int,
  );

  final List<TecnicoEquipo> tecnicos;
  final int pagina;
  final int total;
}

/// Invitación para que el técnico defina su contraseña (`Invitation`): un
/// enlace de un solo uso que vence a las 72 horas. Solo se ve al crearla.
class Invitacion {
  const Invitacion({required this.enlace, required this.venceEn});

  factory Invitacion.desdeJson(Map<String, dynamic> json) => Invitacion(
    enlace: json['link'] as String,
    venceEn: DateTime.parse(json['expiresAt'] as String),
  );

  final String enlace;
  final DateTime venceEn;
}

/// Técnico recién dado de alta con su invitación (`ProviderTechnicianCreated`).
class TecnicoCreado {
  const TecnicoCreado({required this.nombre, required this.invitacion});

  factory TecnicoCreado.desdeJson(Map<String, dynamic> json) => TecnicoCreado(
    nombre: json['fullName'] as String,
    invitacion: Invitacion.desdeJson(
      json['invitation'] as Map<String, dynamic>,
    ),
  );

  final String nombre;
  final Invitacion invitacion;
}

/// Datos del alta (`ProviderTechnicianRequest`): sin contraseña ni rol; el
/// técnico define su contraseña con la invitación.
class DatosAltaTecnico {
  const DatosAltaTecnico({
    required this.nombreCompleto,
    required this.email,
    required this.telefono,
    required this.documento,
    required this.especialidadId,
  });

  final String nombreCompleto;
  final String email;
  final String telefono;
  final String documento;
  final String especialidadId;

  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'fullName': nombreCompleto.trim(),
    'phone': telefono.trim(),
    'documentId': documento.trim(),
    'specialtyId': especialidadId,
  };
}
