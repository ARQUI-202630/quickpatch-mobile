import '../../../core/utils/monto.dart';

/// Estado del pago (`payments.v1.yaml` 1.0.0, esquema `Payment`).
enum EstadoPago {
  pendiente('pendiente'),
  procesando('procesando'),
  aprobado('aprobado'),
  rechazado('rechazado');

  const EstadoPago(this.valor);

  final String valor;

  static EstadoPago desdeValor(String valor) => values.firstWhere(
    (e) => e.valor == valor,
    orElse: () => throw FormatException('Estado de pago desconocido: $valor'),
  );
}

/// Pago de una solicitud completada (RF-22). El monto es el total de la
/// cotización aceptada: la app nunca lo envía.
class Pago {
  const Pago({
    required this.id,
    required this.solicitudId,
    required this.estado,
    required this.monto,
    required this.creadoEn,
    this.motivo,
    this.comprobanteId,
    this.procesadoEn,
  });

  factory Pago.desdeJson(Map<String, dynamic> json) => Pago(
    id: json['paymentId'] as String,
    solicitudId: json['serviceRequestId'] as String,
    estado: EstadoPago.desdeValor(json['status'] as String),
    monto: Monto(json['amount'] as String),
    motivo: json['reasonCode'] as String?,
    comprobanteId: json['invoiceId'] as String?,
    creadoEn: DateTime.parse(json['createdAt'] as String),
    procesadoEn: json['processedAt'] == null
        ? null
        : DateTime.parse(json['processedAt'] as String),
  );

  final String id;
  final String solicitudId;
  final EstadoPago estado;
  final Monto monto;
  final String? motivo;
  final String? comprobanteId;
  final DateTime creadoEn;
  final DateTime? procesadoEn;

  /// Se puede pagar, o reintentar tras un rechazo (RN-SR5).
  bool get sePuedePagar =>
      estado == EstadoPago.pendiente || estado == EstadoPago.rechazado;

  /// El motivo del rechazo en palabras del cliente.
  String get motivoLegible => switch (motivo) {
    'fondos_insuficientes' => 'La tarjeta no tiene fondos suficientes.',
    'pasarela_sin_respuesta' =>
      'La pasarela no respondió y el cobro no se hizo.',
    'token_invalido' => 'La pasarela no reconoció la tarjeta.',
    _ => 'La pasarela rechazó el pago.',
  };
}

/// Tipos de documento del comprobante (esquema `Billing`).
enum TipoDocumento {
  cc('CC', 'Cédula de ciudadanía'),
  ce('CE', 'Cédula de extranjería'),
  nit('NIT', 'NIT'),
  pp('PP', 'Pasaporte');

  const TipoDocumento(this.valor, this.nombre);

  final String valor;
  final String nombre;

  static TipoDocumento desdeValor(String valor) => values.firstWhere(
    (e) => e.valor == valor,
    orElse: () =>
        throw FormatException('Tipo de documento desconocido: $valor'),
  );
}

/// Datos del pagador para el comprobante (RF-24). Nunca datos de la tarjeta.
class DatosFacturacion {
  const DatosFacturacion({
    required this.nombre,
    required this.tipoDocumento,
    required this.numeroDocumento,
    required this.correo,
  });

  final String nombre;
  final TipoDocumento tipoDocumento;
  final String numeroDocumento;
  final String correo;

  Map<String, dynamic> toJson() => {
    'name': nombre.trim(),
    'documentType': tipoDocumento.valor,
    'documentNumber': numeroDocumento.trim(),
    'email': correo.trim(),
  };
}

/// Comprobante de un pago aprobado (RF-24, SCRUM-494; payments 1.1.0,
/// esquema `Invoice`). Es un comprobante de pago sin validez fiscal: no es una
/// factura electrónica (SRS DR-03).
class Comprobante {
  const Comprobante({
    required this.id,
    required this.numero,
    required this.pagoId,
    required this.solicitudId,
    required this.pagador,
    required this.monto,
    required this.moneda,
    required this.concepto,
    required this.emitidoEn,
  });

  factory Comprobante.desdeJson(Map<String, dynamic> json) {
    final pagador = json['payer'] as Map<String, dynamic>;
    return Comprobante(
      id: json['invoiceId'] as String,
      numero: json['invoiceNumber'] as String,
      pagoId: json['paymentId'] as String,
      solicitudId: json['serviceRequestId'] as String,
      pagador: DatosFacturacion(
        nombre: pagador['name'] as String,
        tipoDocumento: TipoDocumento.desdeValor(
          pagador['documentType'] as String,
        ),
        numeroDocumento: pagador['documentNumber'] as String,
        correo: pagador['email'] as String,
      ),
      monto: Monto(json['amount'] as String),
      moneda: json['currency'] as String,
      concepto: json['concept'] as String,
      emitidoEn: DateTime.parse(json['issuedAt'] as String),
    );
  }

  final String id;
  final String numero;
  final String pagoId;
  final String solicitudId;
  final DatosFacturacion pagador;
  final Monto monto;
  final String moneda;
  final String concepto;
  final DateTime emitidoEn;

  /// Nombre del PDF, el mismo que propone el servidor.
  String get archivoPdf => '$numero.pdf';
}
