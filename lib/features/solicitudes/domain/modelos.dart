/// Categoría activa del tenant (`Category` en `catalog.v1.yaml`).
class Categoria {
  const Categoria({required this.id, required this.nombre, this.descripcion});

  factory Categoria.desdeJson(Map<String, dynamic> json) => Categoria(
    id: json['id'] as String,
    nombre: json['name'] as String,
    descripcion: json['description'] as String?,
  );

  final String id;
  final String nombre;
  final String? descripcion;
}

/// Punto geográfico WGS 84 (`GeoPoint` en `service-request.v1.yaml`).
class Ubicacion {
  const Ubicacion(this.latitud, this.longitud);

  factory Ubicacion.desdeJson(Map<String, dynamic> json) => Ubicacion(
    (json['latitude'] as num).toDouble(),
    (json['longitude'] as num).toDouble(),
  );

  final double latitud;
  final double longitud;

  Map<String, dynamic> toJson() => {'latitude': latitud, 'longitude': longitud};
}

/// Datos de `POST /v1/service-requests` (`CreateServiceRequest`).
class NuevaSolicitud {
  const NuevaSolicitud({
    required this.categoriaId,
    required this.descripcion,
    required this.ubicacion,
    required this.direccion,
  });

  final String categoriaId;
  final String descripcion;
  final Ubicacion ubicacion;
  final String direccion;

  Map<String, dynamic> toJson() => {
    'categoryId': categoriaId,
    'description': descripcion.trim(),
    'location': ubicacion.toJson(),
    'addressText': direccion.trim(),
  };
}

/// Estado de la solicitud (`ServiceRequestStatus`, DD 7.4).
enum EstadoSolicitud {
  buscandoTecnico('buscando_tecnico', 'Buscando técnico'),
  enEspera('en_espera', 'En espera'),
  asignado('asignado', 'Técnico asignado'),
  cotizado('cotizado', 'Cotizada'),
  cotizacionAceptada('cotizacion_aceptada', 'Cotización aceptada'),
  enProgreso('en_progreso', 'En progreso'),
  completado('completado', 'Completada'),
  pagado('pagado', 'Pagada'),
  cancelado('cancelado', 'Cancelada');

  const EstadoSolicitud(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static EstadoSolicitud desdeValor(String valor) =>
      values.firstWhere((e) => e.valor == valor);
}

/// Técnico asignado a la solicitud (`AssignedTechnician`, 1.1.0).
class TecnicoAsignado {
  const TecnicoAsignado({required this.id, this.nombre});

  factory TecnicoAsignado.desdeJson(Map<String, dynamic> json) =>
      TecnicoAsignado(
        id: json['id'] as String,
        nombre: json['fullName'] as String?,
      );

  final String id;
  final String? nombre;
}

/// Contacto del cliente (`RequestClient`, 1.1.0). Solo lo recibe el técnico
/// asignado mientras la solicitud está entre `asignado` y `completado`
/// (RN-SR13); si Identity no respondió, nombre y teléfono llegan en `null`.
class ClienteSolicitud {
  const ClienteSolicitud({required this.id, this.nombre, this.telefono});

  factory ClienteSolicitud.desdeJson(Map<String, dynamic> json) =>
      ClienteSolicitud(
        id: json['id'] as String,
        nombre: json['fullName'] as String?,
        telefono: json['phone'] as String?,
      );

  final String id;
  final String? nombre;
  final String? telefono;
}

/// Solicitud creada o consultada (`ServiceRequest`).
class Solicitud {
  const Solicitud({
    required this.id,
    required this.estado,
    required this.categoriaId,
    required this.descripcion,
    required this.ubicacion,
    required this.direccion,
    required this.creadaEn,
    this.tecnicoId,
    this.tecnico,
    this.asignadaEn,
    this.cliente,
  });

  factory Solicitud.desdeJson(Map<String, dynamic> json) => Solicitud(
    id: json['id'] as String,
    estado: EstadoSolicitud.desdeValor(json['status'] as String),
    categoriaId: json['categoryId'] as String,
    descripcion: json['description'] as String,
    ubicacion: Ubicacion.desdeJson(json['location'] as Map<String, dynamic>),
    direccion: json['addressText'] as String,
    creadaEn: DateTime.parse(json['createdAt'] as String),
    tecnicoId: json['technicianId'] as String?,
    tecnico: json['technician'] == null
        ? null
        : TecnicoAsignado.desdeJson(json['technician'] as Map<String, dynamic>),
    asignadaEn: json['assignedAt'] == null
        ? null
        : DateTime.parse(json['assignedAt'] as String),
    cliente: json['client'] == null
        ? null
        : ClienteSolicitud.desdeJson(json['client'] as Map<String, dynamic>),
  );

  final String id;
  final EstadoSolicitud estado;
  final String categoriaId;
  final String descripcion;
  final Ubicacion ubicacion;
  final String direccion;
  final DateTime creadaEn;
  final String? tecnicoId;

  /// Datos del técnico asignado; `null` antes de la asignación (1.1.0).
  final TecnicoAsignado? tecnico;

  /// Momento en que un técnico aceptó la oferta; `null` antes (1.1.0).
  final DateTime? asignadaEn;

  /// Contacto del cliente, solo para el técnico asignado (1.1.0).
  final ClienteSolicitud? cliente;
}

/// Solicitud en la lista del técnico (`TechnicianServiceRequest`,
/// service-request 1.2.0). Sin dirección, ubicación ni cliente (RN-SR13): el
/// detalle sigue en `GET /v1/service-requests/{id}`.
class ServicioTecnico {
  const ServicioTecnico({
    required this.id,
    required this.estado,
    required this.categoriaId,
    required this.descripcion,
    required this.creadaEn,
    required this.asignadaEn,
  });

  factory ServicioTecnico.desdeJson(Map<String, dynamic> json) =>
      ServicioTecnico(
        id: json['id'] as String,
        estado: EstadoSolicitud.desdeValor(json['status'] as String),
        categoriaId: json['categoryId'] as String,
        descripcion: json['description'] as String,
        creadaEn: DateTime.parse(json['createdAt'] as String),
        asignadaEn: DateTime.parse(json['assignedAt'] as String),
      );

  final String id;
  final EstadoSolicitud estado;
  final String categoriaId;
  final String descripcion;
  final DateTime creadaEn;
  final DateTime asignadaEn;
}

/// Página de `GET /v1/technicians/me/service-requests`
/// (`TechnicianServiceRequestPage`).
class PaginaServiciosTecnico {
  const PaginaServiciosTecnico({
    required this.servicios,
    required this.pagina,
    required this.total,
  });

  factory PaginaServiciosTecnico.desdeJson(Map<String, dynamic> json) =>
      PaginaServiciosTecnico(
        servicios: (json['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(ServicioTecnico.desdeJson)
            .toList(),
        pagina: json['page'] as int,
        total: json['totalItems'] as int,
      );

  final List<ServicioTecnico> servicios;
  final int pagina;
  final int total;
}
