import '../../../core/utils/monto.dart';
import 'pago.dart';

/// Filtro de los pagos recibidos. El contrato acepta un solo `status`, así
/// que cada filtro es una consulta paginada aparte.
enum FiltroPagosRecibidos {
  todos(
    'Todos',
    null,
    'Cuando se complete un servicio, su pago aparecerá aquí.',
  ),
  pendientes(
    'Pendientes',
    EstadoPago.pendiente,
    'Aquí aparecen los servicios completados que el cliente aún no paga.',
  ),
  procesando(
    'Procesando',
    EstadoPago.procesando,
    'Aquí aparecen los pagos que la pasarela está confirmando.',
  ),
  recibidos(
    'Recibidos',
    EstadoPago.aprobado,
    'Cuando un cliente pague un servicio, aparecerá aquí.',
  );

  const FiltroPagosRecibidos(this.etiqueta, this.estado, this.mensajeVacio);

  final String etiqueta;

  /// Valor del parámetro `status`; `null` no lo envía.
  final EstadoPago? estado;
  final String mensajeVacio;
}

/// Pago de un servicio que prestó el técnico (`ReceivedPayment`, payments
/// 1.2.0, RF-25). No trae datos de tarjeta (RN-P1). Los rechazados no
/// aparecen: el reintento crea un pago nuevo (RN-P4).
class PagoRecibido {
  const PagoRecibido({
    required this.id,
    required this.solicitudId,
    required this.tecnicoId,
    required this.monto,
    required this.estado,
    required this.creadoEn,
    this.aprobadoEn,
  });

  factory PagoRecibido.desdeJson(Map<String, dynamic> json) => PagoRecibido(
    id: json['id'] as String,
    solicitudId: json['serviceRequestId'] as String,
    tecnicoId: json['technicianId'] as String,
    monto: Monto(json['amount'] as String),
    estado: EstadoPago.desdeValor(json['status'] as String),
    creadoEn: DateTime.parse(json['createdAt'] as String),
    aprobadoEn: json['approvedAt'] == null
        ? null
        : DateTime.parse(json['approvedAt'] as String),
  );

  final String id;
  final String solicitudId;
  final String tecnicoId;
  final Monto monto;
  final EstadoPago estado;

  /// Cuándo se completó el servicio y se creó el pago.
  final DateTime creadoEn;

  /// Cuándo lo aprobó la pasarela; `null` mientras no esté aprobado.
  final DateTime? aprobadoEn;
}

/// Página de pagos recibidos (`ReceivedPaymentPage`).
class PaginaPagosRecibidos {
  const PaginaPagosRecibidos({
    required this.pagos,
    required this.pagina,
    required this.total,
  });

  factory PaginaPagosRecibidos.desdeJson(Map<String, dynamic> json) =>
      PaginaPagosRecibidos(
        pagos: (json['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(PagoRecibido.desdeJson)
            .toList(),
        pagina: json['page'] as int,
        total: json['totalItems'] as int,
      );

  final List<PagoRecibido> pagos;
  final int pagina;
  final int total;
}
