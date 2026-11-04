import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/cliente_api.dart';
import '../domain/pago.dart';
import '../domain/pago_recibido.dart';

/// Pago de la solicitud, su comprobante y los pagos recibidos. Contrato:
/// `payments.v1.yaml` 1.2.0 (`GET` y `POST /v1/service-requests/{id}/payment`,
/// `GET /v1/payments/{id}/invoice` y `GET /v1/payments/received`).
class RepositorioPagos {
  const RepositorioPagos(this._dio);

  final Dio _dio;

  /// Pago más reciente de la solicitud. `404 pago-no-disponible` mientras
  /// Payments no sabe que el servicio se completó.
  Future<Pago> obtener(String solicitudId) => _llamar(() async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.pago(solicitudId),
    );
    return Pago.desdeJson(respuesta.data!);
  });

  /// Paga con el token de la pasarela; nunca con la tarjeta. Responde el pago
  /// `aprobado` o `rechazado`; `409` si ya está en curso o pagado; `502
  /// pasarela-sin-respuesta` si la pasarela no respondió.
  Future<Pago> pagar(
    String solicitudId, {
    required String token,
    required DatosFacturacion facturacion,
  }) => _llamar(() async {
    final respuesta = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.pago(solicitudId),
      data: {'paymentToken': token, 'billing': facturacion.toJson()},
    );
    return Pago.desdeJson(respuesta.data!);
  });

  /// Comprobante del pago aprobado [pagoId] en JSON.
  Future<Comprobante> comprobante(String pagoId) => _llamar(() async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.comprobante(pagoId),
    );
    return Comprobante.desdeJson(respuesta.data!);
  });

  /// El mismo comprobante en PDF (`Accept: application/pdf`).
  Future<Uint8List> comprobantePdf(String pagoId) => _llamar(() async {
    final respuesta = await _dio.get<List<int>>(
      ApiEndpoints.comprobante(pagoId),
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'application/pdf'},
      ),
    );
    return Uint8List.fromList(respuesta.data!);
  });

  /// Elementos por página de los pagos recibidos (DD 8.1).
  static const tamanoPagina = 20;

  /// `GET /v1/payments/received` (payments 1.2.0, RF-25): los del técnico
  /// del token o, para el proveedor, los de su equipo. [tecnicoId] es solo
  /// para el proveedor; el técnico que lo envía recibe `400`.
  Future<PaginaPagosRecibidos> recibidos({
    EstadoPago? estado,
    String? tecnicoId,
    int pagina = 1,
  }) => _llamar(() async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.pagosRecibidos,
      queryParameters: {
        'technicianId': ?tecnicoId,
        'status': ?estado?.valor,
        'page': pagina,
        'size': tamanoPagina,
      },
    );
    return PaginaPagosRecibidos.desdeJson(respuesta.data!);
  });

  Future<T> _llamar<T>(Future<T> Function() llamada) async {
    try {
      return await llamada();
    } on DioException catch (e) {
      throw AppException.desdeDio(e);
    }
  }
}

final repositorioPagosProvider = Provider<RepositorioPagos>(
  (ref) => RepositorioPagos(ref.watch(clienteApiProvider)),
);

final pagoProvider = FutureProvider.autoDispose.family<Pago, String>(
  (ref, solicitudId) =>
      ref.watch(repositorioPagosProvider).obtener(solicitudId),
);

final comprobanteProvider = FutureProvider.autoDispose
    .family<Comprobante, String>(
      (ref, pagoId) => ref.watch(repositorioPagosProvider).comprobante(pagoId),
    );
