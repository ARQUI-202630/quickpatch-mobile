import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/cliente_api.dart';
import '../domain/notificacion.dart';

/// Buzón del usuario de la sesión (`communication.v1.yaml` 1.2.0, ADR-024).
class RepositorioNotificaciones {
  const RepositorioNotificaciones(this._dio);

  final Dio _dio;

  static const tamanoPagina = 20;

  /// Notificaciones de la más reciente a la más antigua.
  Future<PaginaNotificaciones> listar({int pagina = 1}) => _llamar(() async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.notificaciones,
      queryParameters: {'page': pagina, 'size': tamanoPagina},
    );
    return PaginaNotificaciones.desdeJson(respuesta.data!);
  });

  /// Marca la notificación como leída; es idempotente.
  Future<void> marcarLeida(String id) =>
      _llamar(() => _dio.post<void>(ApiEndpoints.notificacionLeida(id)));

  /// Si el usuario todavía puede abrir la solicitud de una notificación
  /// (`GET /v1/service-requests/{id}`, service-request.v1.yaml). Un aviso
  /// viejo puede apuntar a una solicitud que ya no ve: 403 cuando el técnico
  /// queda fuera de asignado a completado (RN-SR13), por ejemplo tras la
  /// tercera cotización rechazada, y 404 si no existe. Otros errores se
  /// propagan: la pantalla del detalle los muestra con su reintento.
  Future<bool> solicitudDisponible(String id) async {
    try {
      await _dio.get<Map<String, dynamic>>(ApiEndpoints.solicitud(id));
      return true;
    } on DioException catch (e) {
      final error = AppException.desdeDio(e);
      if (error.status == 403 || error.status == 404) return false;
      throw error;
    }
  }

  Future<T> _llamar<T>(Future<T> Function() llamada) async {
    try {
      return await llamada();
    } on DioException catch (e) {
      throw AppException.desdeDio(e);
    }
  }
}

final repositorioNotificacionesProvider = Provider<RepositorioNotificaciones>(
  (ref) => RepositorioNotificaciones(ref.watch(clienteApiProvider)),
);
