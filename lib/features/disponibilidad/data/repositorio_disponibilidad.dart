import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/cliente_api.dart';
import '../../../core/network/interceptores.dart';
import '../domain/modelos.dart';

/// Disponibilidad y cobertura del técnico autenticado (RF-13, SCRUM-33).
/// Contrato: `matching.v1.yaml`. El técnico sale del token: ninguna ruta lleva
/// su identificador ni el tenant (RN-U3).
class RepositorioDisponibilidad {
  const RepositorioDisponibilidad(this._dio);

  final Dio _dio;

  /// `GET /v1/localities`: catálogo igual para todos los tenants, sin token.
  Future<List<Localidad>> localidades() => _llamar(() async {
    final respuesta = await _dio.get<List<dynamic>>(
      ApiEndpoints.localidades,
      options: opcionesPublicas(),
    );
    return respuesta.data!
        .cast<Map<String, dynamic>>()
        .map(Localidad.desdeJson)
        .toList();
  });

  Future<Disponibilidad> disponibilidad() => _llamar(() async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.disponibilidad,
    );
    return Disponibilidad.desdeJson(respuesta.data!);
  });

  /// `PUT availability`. Si el técnico está ocupado responde 409 (RN-M6).
  Future<Disponibilidad> cambiarDisponibilidad({required bool disponible}) =>
      _llamar(() async {
        final respuesta = await _dio.put<Map<String, dynamic>>(
          ApiEndpoints.disponibilidad,
          data: {
            'status': disponible
                ? EstadoDisponibilidad.disponible.valor
                : EstadoDisponibilidad.noDisponible.valor,
          },
        );
        return Disponibilidad.desdeJson(respuesta.data!);
      });

  Future<Cobertura> cobertura() => _llamar(() async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.cobertura,
    );
    return Cobertura.desdeJson(respuesta.data!);
  });

  /// `PUT coverage`: reemplaza la lista completa (mínimo 1, máximo 20).
  Future<Cobertura> reemplazarCobertura(List<String> codigos) =>
      _llamar(() async {
        final respuesta = await _dio.put<Map<String, dynamic>>(
          ApiEndpoints.cobertura,
          data: {'localityCodes': codigos},
        );
        return Cobertura.desdeJson(respuesta.data!);
      });

  Future<T> _llamar<T>(Future<T> Function() llamada) async {
    try {
      return await llamada();
    } on DioException catch (e) {
      throw AppException.desdeDio(e);
    }
  }
}

final repositorioDisponibilidadProvider = Provider<RepositorioDisponibilidad>(
  (ref) => RepositorioDisponibilidad(ref.watch(clienteApiProvider)),
);

final localidadesProvider = FutureProvider.autoDispose<List<Localidad>>(
  (ref) => ref.watch(repositorioDisponibilidadProvider).localidades(),
);

final disponibilidadProvider = FutureProvider.autoDispose<Disponibilidad>(
  (ref) => ref.watch(repositorioDisponibilidadProvider).disponibilidad(),
);

final coberturaProvider = FutureProvider.autoDispose<Cobertura>(
  (ref) => ref.watch(repositorioDisponibilidadProvider).cobertura(),
);
