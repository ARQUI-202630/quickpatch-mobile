import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/cliente_api.dart';
import '../domain/oferta.dart';

/// Ofertas del técnico (`matching.v1.yaml` 1.0.0, RF-10): consultar la
/// pendiente, aceptarla o rechazarla.
class RepositorioOfertas {
  const RepositorioOfertas(this._dio);

  final Dio _dio;

  /// La oferta pendiente y vigente del técnico, o `null` si no tiene. Un
  /// técnico tiene a lo sumo una a la vez (RN-M7).
  Future<Oferta?> pendiente() => _llamar(() async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.ofertas,
      queryParameters: {'status': 'pendiente'},
    );
    final items = respuesta.data!['items'] as List<dynamic>;
    return items.isEmpty
        ? null
        : Oferta.desdeJson(items.first as Map<String, dynamic>);
  });

  /// Acepta la oferta: el técnico queda ocupado y Matching publica
  /// `matching.technician-assigned`. 409 `oferta-no-disponible` si venció,
  /// es ajena o ya se respondió; 409 `tecnico-no-disponible` si el técnico
  /// ya no está disponible.
  Future<void> aceptar(String attemptId) =>
      _llamar(() => _dio.post<void>(ApiEndpoints.aceptarOferta(attemptId)));

  /// Rechaza la oferta, sin penalización (RF-10): Matching la ofrece al
  /// siguiente candidato.
  Future<void> rechazar(String attemptId) =>
      _llamar(() => _dio.post<void>(ApiEndpoints.rechazarOferta(attemptId)));

  Future<T> _llamar<T>(Future<T> Function() llamada) async {
    try {
      return await llamada();
    } on DioException catch (e) {
      throw AppException.desdeDio(e);
    }
  }
}

final repositorioOfertasProvider = Provider<RepositorioOfertas>(
  (ref) => RepositorioOfertas(ref.watch(clienteApiProvider)),
);

/// Oferta pendiente del técnico de la sesión.
final ofertaPendienteProvider = FutureProvider.autoDispose<Oferta?>(
  (ref) => ref.watch(repositorioOfertasProvider).pendiente(),
);
