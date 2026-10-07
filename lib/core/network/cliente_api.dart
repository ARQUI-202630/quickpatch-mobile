import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
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
      headers: {if (config.hostHeader.isNotEmpty) 'Host': config.hostHeader},
    ),
  );
  if (config.certificadoSha256.isNotEmpty) {
    final huella = normalizarHuella(config.certificadoSha256);
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () =>
          HttpClient()
            ..badCertificateCallback = (certificado, _, _) =>
                certificadoCoincide(certificado.der, huella),
    );
  }
  dio.interceptors.addAll(interceptores);
  return dio;
}

/// Huella en minúsculas y sin separadores (`openssl` la entrega con `:`).
String normalizarHuella(String huella) =>
    huella.replaceAll(':', '').trim().toLowerCase();

/// `true` si el certificado (DER) tiene la huella SHA-256 esperada.
bool certificadoCoincide(List<int> der, String huellaNormalizada) =>
    sha256.convert(der).toString() == huellaNormalizada;

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
