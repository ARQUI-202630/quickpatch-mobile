import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/cliente_api.dart';
import '../../../core/utils/monto.dart';
import '../domain/modelos.dart';

/// Solicitudes del cliente y del técnico. Contrato: `service-request.v1.yaml`
/// (`POST /v1/service-requests`, `GET /v1/service-requests/{id}` y, para el
/// técnico, `GET /v1/technicians/me/service-requests` desde 1.2.0; la
/// cancelación, `POST /v1/service-requests/{id}/cancel`, desde 1.5.0; las
/// cotizaciones, `/v1/service-requests/{id}/quotes`, desde 1.6.0; iniciar,
/// evidencias y completar desde 1.7.0).
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

  /// Cotizaciones de la solicitud, de la más antigua a la más reciente
  /// (RF-34, RF-35). Las ven el cliente dueño y el técnico asignado.
  Future<List<Cotizacion>> cotizaciones(String id) => _llamar(() async {
    final respuesta = await _dio.get<List<dynamic>>(
      ApiEndpoints.cotizaciones(id),
    );
    return respuesta.data!
        .cast<Map<String, dynamic>>()
        .map(Cotizacion.desdeJson)
        .toList();
  });

  /// El técnico asignado cotiza (RF-34). Los montos van como texto con dos
  /// decimales (`Money`). `409 transicion-invalida` si la solicitud ya no está
  /// en `asignado`; `409 limite-de-cotizaciones` si ya emitió 3.
  Future<Cotizacion> cotizar(
    String id, {
    required Monto manoDeObra,
    required Monto materiales,
    String? detalle,
  }) => _llamar(() async {
    final texto = detalle?.trim();
    final respuesta = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.cotizaciones(id),
      data: {
        'laborAmount': manoDeObra.valor,
        'materialsAmount': materiales.valor,
        if (texto != null && texto.isNotEmpty) 'detail': texto,
      },
    );
    return Cotizacion.desdeJson(respuesta.data!);
  });

  /// El cliente acepta la cotización pendiente (RF-35). `409
  /// transicion-invalida` si ya venció o ya se respondió.
  Future<DecisionCotizacion> aceptarCotizacion(
    String id,
    String cotizacionId,
  ) => _llamar(() async {
    final respuesta = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.aceptarCotizacion(id, cotizacionId),
    );
    return DecisionCotizacion.desdeJson(respuesta.data!);
  });

  /// El cliente rechaza la cotización pendiente, con un motivo opcional
  /// (RF-35). Sin motivo no se envía cuerpo. La tercera cancela la solicitud.
  Future<DecisionCotizacion> rechazarCotizacion(
    String id,
    String cotizacionId, {
    String? motivo,
  }) => _llamar(() async {
    final texto = motivo?.trim();
    final respuesta = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.rechazarCotizacion(id, cotizacionId),
      data: texto == null || texto.isEmpty ? null : {'reason': texto},
    );
    return DecisionCotizacion.desdeJson(respuesta.data!);
  });

  /// El técnico asignado inicia el servicio (RF-14). `409 transicion-invalida`
  /// si la solicitud no está en `cotizacion_aceptada` (RN-SR6).
  Future<void> iniciar(String id) => _llamar(() async {
    await _dio.post<Map<String, dynamic>>(ApiEndpoints.iniciar(id));
  });

  /// El técnico asignado completa el servicio (RF-15). `422
  /// evidencia-requerida` sin fotos (RN-SR3); `409 transicion-invalida` si no
  /// está en `en_progreso`.
  Future<void> completar(String id) => _llamar(() async {
    await _dio.post<Map<String, dynamic>>(ApiEndpoints.completar(id));
  });

  /// Fotos de evidencia de la solicitud, de la más antigua a la más reciente.
  /// Las ven el cliente dueño y el técnico asignado.
  Future<List<Evidencia>> evidencias(String id) => _llamar(() async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.evidencias(id),
    );
    return (respuesta.data!['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Evidencia.desdeJson)
        .toList();
  });

  /// Sube una foto en el campo `file` (`multipart/form-data`). El backend
  /// reconoce el tipo por el contenido: `400` con el error en `file` si no es
  /// JPEG, PNG o WebP de hasta 10 MB; `409 limite-de-evidencias` con 10.
  Future<Evidencia> subirEvidencia(
    String id,
    Uint8List foto, {
    required String nombre,
    void Function(double avance)? alAvanzar,
  }) => _llamar(() async {
    final respuesta = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.evidencias(id),
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(foto, filename: nombre),
      }),
      onSendProgress: alAvanzar == null
          ? null
          : (enviados, total) {
              if (total > 0) alAvanzar(enviados / total);
            },
    );
    return Evidencia.desdeJson(respuesta.data!);
  });

  /// Archivo de una foto, con el token de la sesión: la URL sola no sirve.
  Future<Uint8List> archivoEvidencia(String id, String evidenciaId) =>
      _llamar(() async {
        final respuesta = await _dio.get<List<int>>(
          ApiEndpoints.archivoEvidencia(id, evidenciaId),
          options: Options(responseType: ResponseType.bytes),
        );
        return Uint8List.fromList(respuesta.data!);
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

/// Cotizaciones de una solicitud (service-request 1.6.0).
final cotizacionesProvider = FutureProvider.autoDispose
    .family<List<Cotizacion>, String>(
      (ref, id) => ref.watch(repositorioSolicitudesProvider).cotizaciones(id),
    );

/// Fotos de evidencia de una solicitud (service-request 1.7.0).
final evidenciasProvider = FutureProvider.autoDispose
    .family<List<Evidencia>, String>(
      (ref, id) => ref.watch(repositorioSolicitudesProvider).evidencias(id),
    );

/// Bytes de una foto de evidencia. El archivo no cambia, así que se conserva
/// mientras la pantalla lo use.
final archivoEvidenciaProvider = FutureProvider.autoDispose
    .family<Uint8List, ({String solicitudId, String evidenciaId})>(
      (ref, clave) => ref
          .watch(repositorioSolicitudesProvider)
          .archivoEvidencia(clave.solicitudId, clave.evidenciaId),
    );
