import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuración del entorno en que corre la app.
///
/// Los valores llegan con `--dart-define-from-file=config/<entorno>.json`
/// (ver `.vscode/launch.json`). Nunca se guardan secretos aquí: estos valores
/// quedan dentro del APK.
class AppConfig {
  const AppConfig({
    required this.entorno,
    required this.apiBaseUrl,
    required this.canalId,
    this.hostHeader = '',
    this.certificadoSha256 = '',
  });

  /// Lee la configuración de las variables de compilación.
  factory AppConfig.desdeEntorno() => const AppConfig(
    entorno: String.fromEnvironment('ENTORNO', defaultValue: 'dev'),
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8080/api',
    ),
    canalId: String.fromEnvironment(
      'CHANNEL_ID',
      defaultValue: 'quickpatch-mobile',
    ),
    hostHeader: String.fromEnvironment('HOST_HEADER'),
    certificadoSha256: String.fromEnvironment('CERT_SHA256'),
  );

  /// `dev` o `qa`.
  final String entorno;

  /// URL del API Gateway con el prefijo `/api` (DD, sección 8.1).
  final String apiBaseUrl;

  /// Valor de `X-Channel-Id` para las peticiones públicas. El Gateway lo
  /// traduce al tenant (RN-U5); su formato definitivo depende de DEP-09.
  final String canalId;

  /// Nombre que se envía en la cabecera `Host` cuando [apiBaseUrl] usa la IP
  /// de VM1: un teléfono no puede editar su archivo `hosts`, y el Nginx de VM1
  /// elige el ambiente por nombre (Documento de Infraestructura, 11.2).
  /// Vacío: se usa el nombre de la URL.
  final String hostHeader;

  /// Huella SHA-256 del certificado autofirmado del gateway (R9, sin CA
  /// pública). Si se define, la app confía solo en ese certificado; vacío: se
  /// validan los certificados con las CA del sistema.
  final String certificadoSha256;

  /// El registro de empresa cliente (RF-06) depende de `client_companies`
  /// (DD 3.1, pendiente de aprobación): se habilita cuando Identity publique
  /// `POST /v1/auth/register/company`.
  static const registroEmpresaHabilitado = false;
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.desdeEntorno(),
);
