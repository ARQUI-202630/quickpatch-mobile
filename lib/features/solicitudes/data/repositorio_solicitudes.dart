import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/cliente_api.dart';
import '../domain/modelos.dart';

/// Solicitudes del cliente y del técnico. Contrato: `service-request.v1.yaml`
/// (`POST /v1/service-requests`, `GET /v1/service-requests/{id}` y, para el
/// técnico, `GET /v1/technicians/me/service-requests` desde 1.2.0; la
/// cancelación, `POST /v1/service-requests/{id}/cancel`, desde 1.5.0).
class RepositorioSolicitudes {
  const RepositorioSolicitudes(this._dio);

  final Dio _dio;

  Future<Solicitud> crear(NuevaSolicitud datos) => _llamar(() async {
    final respuesta = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.solicitudes,
      data: datos.toJson(),
    );
    return Solicitud.desdeJson(respuesta.data!);
  });

  /// Ubica la dirección en Bogotá sin crear nada (`POST
  /// /v1/service-requests/location-preview`, 1.3.0). `422
  /// direccion-no-encontrada` o `ubicacion-fuera-de-cobertura` si no puede.
  Future<VistaPreviaUbicacion> vistaPrevia(String direccion) =>
      _llamar(() async {
        final respuesta = await _dio.post<Map<String, dynamic>>(
          ApiEndpoints.vistaPreviaUbicacion,
          data: {'addressText': direccion.trim()},
        );
        return VistaPreviaUbicacion.desdeJson(respuesta.data!);
      });

  Future<Solicitud> obtener(String id) => _llamar(() async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.solicitud(id),
    );
    return Solicitud.desdeJson(respuesta.data!);
  });

  /// Cancela la solicitud antes de que inicie el servicio (RF-36). `409
  /// transicion-invalida` si ya inició; `400` con el campo `reason` si el
  /// motivo no cumple los límites.
  Future<void> cancelar(String id, String motivo) => _llamar(() async {
    await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.cancelar(id),
      data: {'reason': motivo.trim()},
    );
  });

  static const tamanoPagina = 20;

  /// Solicitudes asignadas al técnico de la sesión, de la asignación más
  /// reciente a la más antigua (RF-17). [estado] filtra por uno solo.
  Future<PaginaServiciosTecnico> serviciosDelTecnico({
    EstadoSolicitud? estado,
    int pagina = 1,
  }) => _llamar(() async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.historialTecnico,
      queryParameters: {
        'status': ?estado?.valor,
        'page': pagina,
        'size': tamanoPagina,
      },
    );
    return PaginaServiciosTecnico.desdeJson(respuesta.data!);
  });

  Future<T> _llamar<T>(Future<T> Function() llamada) async {
    try {
      return await llamada();
    } on DioException catch (e) {
      throw AppException.desdeDio(e);
    }
  }
}

final repositorioSolicitudesProvider = Provider<RepositorioSolicitudes>(
  (ref) => RepositorioSolicitudes(ref.watch(clienteApiProvider)),
);

/// Detalle de una solicitud.
final solicitudProvider = FutureProvider.autoDispose.family<Solicitud, String>(
  (ref, id) => ref.watch(repositorioSolicitudesProvider).obtener(id),
);
