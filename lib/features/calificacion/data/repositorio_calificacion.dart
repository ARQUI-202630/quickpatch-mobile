import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/cliente_api.dart';
import '../domain/calificacion.dart';

/// Calificación del servicio (SCRUM-86). Contrato: service-request 1.10.0.
class RepositorioCalificacion {
  const RepositorioCalificacion(this._dio);

  final Dio _dio;

  /// `POST /v1/service-requests/{id}/rating`. Un [comentario] vacío no se
  /// envía, porque es opcional.
  Future<Calificacion> calificar(
    String solicitudId, {
    required int puntaje,
    String comentario = '',
  }) async {
    try {
      final respuesta = await _dio.post<Map<String, dynamic>>(
        '${ApiEndpoints.solicitudes}/$solicitudId/rating',
        data: {
          'score': puntaje,
          if (comentario.isNotEmpty) 'comment': comentario,
        },
      );
      return Calificacion.desdeJson(respuesta.data!);
    } on DioException catch (e) {
      throw AppException.desdeDio(e);
    }
  }
}

final repositorioCalificacionProvider = Provider<RepositorioCalificacion>(
  (ref) => RepositorioCalificacion(ref.watch(clienteApiProvider)),
);
