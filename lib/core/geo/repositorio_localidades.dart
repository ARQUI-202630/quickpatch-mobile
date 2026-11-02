import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_exception.dart';
import '../network/api_endpoints.dart';
import '../network/cliente_api.dart';
import '../network/interceptores.dart';
import 'localidad.dart';
import 'mapa_localidades.dart';

/// Localidades de Bogotá D.C.: el catálogo de Matching y sus límites para el
/// mapa. Lo usan la cobertura del técnico (SCRUM-89) y el detalle de la
/// solicitud asignada (SCRUM-92).
class RepositorioLocalidades {
  const RepositorioLocalidades(this._dio);

  final Dio _dio;

  /// `GET /v1/service-requests/localities` (`service-request.v1.yaml` 1.8.0, ADR-025): catálogo igual para todos los
  /// tenants, sin token.
  Future<List<Localidad>> localidades() async {
    try {
      final respuesta = await _dio.get<List<dynamic>>(
        ApiEndpoints.localidades,
        options: opcionesPublicas(),
      );
      return respuesta.data!
          .cast<Map<String, dynamic>>()
          .map(Localidad.desdeJson)
          .toList();
    } on DioException catch (e) {
      throw AppException.desdeDio(e);
    }
  }
}

final repositorioLocalidadesProvider = Provider<RepositorioLocalidades>(
  (ref) => RepositorioLocalidades(ref.watch(clienteApiProvider)),
);

final localidadesProvider = FutureProvider.autoDispose<List<Localidad>>(
  (ref) => ref.watch(repositorioLocalidadesProvider).localidades(),
);

/// Límites de las localidades para el mapa de cobertura (SCRUM-89). Es un
/// asset de la app: no depende de ningún servicio externo (R5, ADR-024).
const rutaMapaLocalidades = 'assets/geo/localidades_bogota.geojson';

final mapaLocalidadesProvider = FutureProvider<MapaLocalidades>(
  (ref) async => MapaLocalidades.desdeGeoJson(
    await rootBundle.loadString(rutaMapaLocalidades),
  ),
);
