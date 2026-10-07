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
  );

  final String id;
  final EstadoSolicitud estado;
  final String categoriaId;
  final String descripcion;
  final Ubicacion ubicacion;
  final String direccion;
  final DateTime creadaEn;
  final String? tecnicoId;
}
