import '../../../core/geo/localidad.dart';
import '../../../core/utils/monto.dart';

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
    required this.direccion,
    this.ubicacion,
    this.sede,
  });

  final String categoriaId;
  final String descripcion;

  /// Solo del `empresa_contacto` (service-request 1.9.0): nombre de la sede
  /// de la empresa. La empresa y el tipo de cliente salen del token.
  final String? sede;

  /// Opcional desde service-request 1.3.0: sin ella, ServiceRequest
  /// geocodifica [direccion] dentro de Bogotá (ADR-024).
  final Ubicacion? ubicacion;
  final String direccion;

  Map<String, dynamic> toJson() => {
    'categoryId': categoriaId,
    'description': descripcion.trim(),
    'location': ?ubicacion?.toJson(),
    'addressText': direccion.trim(),
    if (sede != null && sede!.trim().isNotEmpty) 'siteName': sede!.trim(),
  };
}

/// Tipo de cliente de la solicitud (`ClientType`, service-request 1.9.0).
enum TipoCliente {
  hogar('hogar'),
  empresa('empresa');

  const TipoCliente(this.valor);

  final String valor;

  /// Un backend anterior a la 1.9.0 no lo envía: es de hogar.
  static TipoCliente desdeValor(String? valor) =>
      valor == 'empresa' ? empresa : hogar;
}

/// Dónde ubicó el geocodificador una dirección (`LocationPreview`,
/// service-request 1.3.0), para que el cliente confirme antes de crear la
/// solicitud. Nominatim no usa el número de casa: ubica la calle o el barrio.
class VistaPreviaUbicacion {
  const VistaPreviaUbicacion({
    required this.ubicacion,
    required this.localidad,
    required this.direccionReconocida,
  });

  factory VistaPreviaUbicacion.desdeJson(
    Map<String, dynamic> json,
  ) => VistaPreviaUbicacion(
    ubicacion: Ubicacion.desdeJson(json['location'] as Map<String, dynamic>),
    localidad: Localidad.desdeJson(json['locality'] as Map<String, dynamic>),
    direccionReconocida: json['matchedAddress'] as String,
  );

  final Ubicacion ubicacion;
  final Localidad localidad;
  final String direccionReconocida;
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

  /// Estados anteriores al inicio del servicio, desde los que se puede
  /// cancelar (RN-SR7; service-request 1.5.0).
  bool get cancelable => switch (this) {
    buscandoTecnico ||
    enEspera ||
    asignado ||
    cotizado ||
    cotizacionAceptada => true,
    enProgreso || completado || pagado || cancelado => false,
  };
}

/// Límites del motivo de cancelación (`CancelServiceRequest`, 1.5.0).
abstract final class MotivoCancelacion {
  static const minimo = 5;
  static const maximo = 500;
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
    this.canceladaEn,
    this.motivoCancelacion,
    this.iniciadaEn,
    this.completadaEn,
    this.tipoCliente = TipoCliente.hogar,
    this.sede,
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
    canceladaEn: json['cancelledAt'] == null
        ? null
        : DateTime.parse(json['cancelledAt'] as String),
    motivoCancelacion: json['cancellationReason'] as String?,
    iniciadaEn: json['startedAt'] == null
        ? null
        : DateTime.parse(json['startedAt'] as String),
    completadaEn: json['completedAt'] == null
        ? null
        : DateTime.parse(json['completedAt'] as String),
    tipoCliente: TipoCliente.desdeValor(json['clientType'] as String?),
    sede: json['siteName'] as String?,
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

  /// Momento y motivo de la cancelación; `null` si no se canceló (1.5.0).
  final DateTime? canceladaEn;
  final String? motivoCancelacion;

  /// Inicio y fin del servicio; `null` antes de cada paso (1.7.0).
  final DateTime? iniciadaEn;
  final DateTime? completadaEn;

  /// Hogar o empresa, y la sede de la empresa (1.9.0).
  final TipoCliente tipoCliente;
  final String? sede;
}

/// Solicitud en la lista del cliente o de la empresa (`AdminServiceRequest`,
/// service-request 1.9.0). Sin dirección, ubicación ni contacto: el detalle
/// sigue en `GET /v1/service-requests/{id}`.
class SolicitudResumen {
  const SolicitudResumen({
    required this.id,
    required this.estado,
    required this.categoriaId,
    required this.clienteId,
    required this.descripcion,
    required this.creadaEn,
    this.tipoCliente = TipoCliente.hogar,
    this.sede,
  });

  factory SolicitudResumen.desdeJson(Map<String, dynamic> json) =>
      SolicitudResumen(
        id: json['id'] as String,
        estado: EstadoSolicitud.desdeValor(json['status'] as String),
        categoriaId: json['categoryId'] as String,
        clienteId: json['clientId'] as String,
        descripcion: json['description'] as String? ?? '',
        creadaEn: DateTime.parse(json['createdAt'] as String),
        tipoCliente: TipoCliente.desdeValor(json['clientType'] as String?),
        sede: json['siteName'] as String?,
      );

  final String id;
  final EstadoSolicitud estado;
  final String categoriaId;

  /// Quien la creó: en una empresa puede ser otro usuario (RN-SR14).
  final String clienteId;
  final String descripcion;
  final DateTime creadaEn;
  final TipoCliente tipoCliente;
  final String? sede;
}

/// Página de `GET /v1/service-requests` (`AdminServiceRequestPage`).
class PaginaSolicitudes {
  const PaginaSolicitudes({
    required this.solicitudes,
    required this.pagina,
    required this.total,
  });

  factory PaginaSolicitudes.desdeJson(Map<String, dynamic> json) =>
      PaginaSolicitudes(
        solicitudes: (json['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(SolicitudResumen.desdeJson)
            .toList(),
        pagina: json['page'] as int,
        total: json['totalItems'] as int,
      );

  final List<SolicitudResumen> solicitudes;
  final int pagina;
  final int total;
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

/// Estado de la cotización (`QuoteStatus`, service-request 1.6.0; DD 5.11).
enum EstadoCotizacion {
  pendiente('pendiente', 'Pendiente'),
  aceptada('aceptada', 'Aceptada'),
  rechazada('rechazada', 'Rechazada'),
  anulada('anulada', 'Anulada'),
  expirada('expirada', 'Vencida');

  const EstadoCotizacion(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static EstadoCotizacion desdeValor(String valor) =>
      values.firstWhere((e) => e.valor == valor);
}

/// Límites de la cotización (`IssueQuote` y `RejectQuote`, 1.6.0; RN-Q7).
abstract final class LimitesCotizacion {
  /// Cotizaciones por solicitud: la cuarta responde `409
  /// limite-de-cotizaciones`.
  static const maximo = 3;

  /// `Money` admite hasta 10 dígitos enteros.
  static const digitosMaximos = 10;
  static const detalleMaximo = 1000;
  static const motivoMinimo = 5;
  static const motivoMaximo = 500;
}

/// Cotización de la solicitud (`Quote`, service-request 1.6.0). Los montos
/// llegan como texto con dos decimales y se conservan así ([Monto]).
class Cotizacion {
  const Cotizacion({
    required this.id,
    required this.numero,
    required this.estado,
    required this.manoDeObra,
    required this.materiales,
    required this.total,
    required this.creadaEn,
    required this.venceEn,
    this.detalle,
    this.respondidaEn,
    this.motivoRechazo,
  });

  factory Cotizacion.desdeJson(Map<String, dynamic> json) => Cotizacion(
    id: json['id'] as String,
    numero: json['quoteNumber'] as int,
    estado: EstadoCotizacion.desdeValor(json['status'] as String),
    manoDeObra: Monto(json['laborAmount'] as String),
    materiales: Monto(json['materialsAmount'] as String),
    total: Monto(json['totalAmount'] as String),
    detalle: json['detail'] as String?,
    creadaEn: DateTime.parse(json['createdAt'] as String),
    venceEn: DateTime.parse(json['expiresAt'] as String),
    respondidaEn: json['respondedAt'] == null
        ? null
        : DateTime.parse(json['respondedAt'] as String),
    motivoRechazo: json['rejectionReason'] as String?,
  );

  final String id;

  /// Posición en la solicitud, de 1 a 3 (RN-Q7).
  final int numero;
  final EstadoCotizacion estado;
  final Monto manoDeObra;
  final Monto materiales;
  final Monto total;
  final String? detalle;
  final DateTime creadaEn;

  /// Límite para responder (RN-Q8); después la solicitud se cancela.
  final DateTime venceEn;
  final DateTime? respondidaEn;
  final String? motivoRechazo;

  /// Si el cliente todavía puede aceptarla o rechazarla en [ahora].
  bool respondibleEn(DateTime ahora) =>
      estado == EstadoCotizacion.pendiente && ahora.isBefore(venceEn);

  /// Si al rechazarla se cancela la solicitud (la tercera, RN-Q7).
  bool get esLaUltima => numero >= LimitesCotizacion.maximo;
}

/// Resultado de aceptar o rechazar (`QuoteDecision`, 1.6.0).
class DecisionCotizacion {
  const DecisionCotizacion({
    required this.cotizacionId,
    required this.estadoCotizacion,
    required this.estadoSolicitud,
    required this.restantes,
  });

  factory DecisionCotizacion.desdeJson(Map<String, dynamic> json) =>
      DecisionCotizacion(
        cotizacionId: json['quoteId'] as String,
        estadoCotizacion: EstadoCotizacion.desdeValor(
          json['quoteStatus'] as String,
        ),
        estadoSolicitud: EstadoSolicitud.desdeValor(
          json['serviceRequestStatus'] as String,
        ),
        restantes: json['remainingQuotes'] as int,
      );

  final String cotizacionId;
  final EstadoCotizacion estadoCotizacion;
  final EstadoSolicitud estadoSolicitud;

  /// Cotizaciones que el técnico todavía puede emitir.
  final int restantes;
}

/// Límites de la evidencia del servicio (service-request 1.7.0, DD 8.3.10).
abstract final class LimitesEvidencia {
  /// Fotos por solicitud (RN-E4).
  static const maximo = 10;

  /// Tamaño máximo de una foto: 10 MB.
  static const bytesMaximos = 10 * 1024 * 1024;
}

/// Foto de evidencia (`Evidence`, service-request 1.7.0). El archivo se
/// descarga aparte con su `id`; la app nunca recibe dónde está guardado.
class Evidencia {
  const Evidencia({required this.id, required this.subidaEn});

  factory Evidencia.desdeJson(Map<String, dynamic> json) => Evidencia(
    id: json['id'] as String,
    subidaEn: DateTime.parse(json['uploadedAt'] as String),
  );

  final String id;
  final DateTime subidaEn;
}
