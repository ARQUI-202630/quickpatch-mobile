import 'package:crypto/crypto.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/core/config/app_config.dart';
import 'package:quickpatch_mobile/core/network/cliente_api.dart';

void main() {
  const base = AppConfig(
    entorno: 'qa',
    apiBaseUrl: 'https://10.43.100.168/api',
    canalId: 'quickpatch-mobile',
  );

  test('sin Host ni certificado fijado usa la configuración estándar', () {
    final dio = crearClienteApi(base, []);
    expect(dio.options.headers.containsKey('Host'), isFalse);
    expect(dio.options.baseUrl, 'https://10.43.100.168/api');
    expect(
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient,
      isNull,
    );
  });

  test(
    'con HOST_HEADER y CERT_SHA256 envía el nombre y fija el certificado',
    () {
      const qa = AppConfig(
        entorno: 'qa',
        apiBaseUrl: 'https://10.43.100.168/api',
        canalId: 'quickpatch-mobile',
        hostHeader: 'qa.quickpatch.internal',
        certificadoSha256: 'AB:CD',
      );
      final dio = crearClienteApi(qa, []);
      expect(dio.options.headers['Host'], 'qa.quickpatch.internal');
      final adaptador = dio.httpClientAdapter as IOHttpClientAdapter;
      expect(adaptador.createHttpClient, isNotNull);
    },
  );

  test('la huella se normaliza y solo acepta el certificado esperado', () {
    final der = [1, 2, 3, 4];
    final huella = sha256.convert(der).toString();
    final conDosPuntos = [
      for (var i = 0; i < huella.length; i += 2) huella.substring(i, i + 2),
    ].join(':').toUpperCase();

    final normalizada = normalizarHuella(conDosPuntos);
    expect(normalizada, huella);
    expect(certificadoCoincide(der, normalizada), isTrue);
    expect(certificadoCoincide([9, 9, 9], normalizada), isFalse);
  });
}
