import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/autenticacion/presentation/controlador_sesion.dart';
import '../config/app_config.dart';
import '../session/almacen_sesion.dart';
import 'interceptores.dart';

/// Crea el cliente HTTP hacia el API Gateway.
Dio crearClienteApi(AppConfig config, List<Interceptor> interceptores) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );
  dio.interceptors.addAll(interceptores);
  return dio;
}

final clienteApiProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final almacen = ref.watch(almacenSesionProvider);
  return crearClienteApi(config, [
    InterceptorCorrelacion(),
    InterceptorAutenticacion(
      obtenerToken: () => almacen.actual?.accessToken,
      canalId: config.canalId,
      alNoAutenticado: () =>
          ref.read(controladorSesionProvider.notifier).cerrarSesion(),
    ),
  ]);
});
