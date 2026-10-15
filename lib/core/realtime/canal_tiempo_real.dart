import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../network/cliente_api.dart';
import '../session/controlador_sesion.dart';
import '../session/rol_usuario.dart';
import 'mensaje_tiempo_real.dart';

/// Conexión WebSocket que usa el canal. En producción es la de `dart:io`; las
/// pruebas la reemplazan.
abstract interface class ConexionWs {
  /// Tramas que envía el servidor; termina cuando se cierra la conexión.
  Stream<dynamic> get tramas;

  void enviar(String trama);

  /// Código de cierre (RFC 6455), disponible cuando [tramas] terminó.
  int? get codigoCierre;

  Future<void> cerrar();
}

typedef ConectorWs = Future<ConexionWs> Function(Uri url);

/// Estado de la conexión, para que la pantalla muestre "En vivo" o el
/// respaldo por consulta.
enum EstadoCanal { conectando, conectado, desconectado, detenido }

/// Canal de estado en tiempo real `/v1/realtime` (`realtime.v1.yaml`, ADR-023).
///
/// 1. Abre el WebSocket (la URL no lleva el token).
/// 2. Envía una única trama `auth` con el token de acceso.
/// 3. Tras `auth.accepted` publica en [avisos] los mensajes del servidor.
///
/// Si la conexión falla o se cierra con 1001, 1011 o 4004 se reconecta con
/// espera creciente (1, 2, 4… hasta 60 s). Con 4000 a 4003 no reintenta; con
/// 4001 (token inválido) llama a [alTokenInvalido].
class CanalTiempoReal {
  CanalTiempoReal({
    required this.url,
    required this.obtenerToken,
    required this.conectar,
    this.alTokenInvalido,
    Duration Function(int intento)? espera,
  }) : _espera = espera ?? esperaCreciente;

  final Uri url;
  final String? Function() obtenerToken;
  final ConectorWs conectar;
  final VoidCallback? alTokenInvalido;
  final Duration Function(int intento) _espera;

  final _avisos = StreamController<MensajeTiempoReal>.broadcast();
  final estado = ValueNotifier<EstadoCanal>(EstadoCanal.desconectado);

  ConexionWs? _conexion;
  StreamSubscription<dynamic>? _suscripcion;
  Timer? _reintento;
  int _intentos = 0;
  bool _cerrado = false;

  /// Avisos ya autenticados: cambios de estado, ofertas y conteos.
  Stream<MensajeTiempoReal> get avisos => _avisos.stream;

  /// 1, 2, 4, 8, 16, 32 y luego 60 segundos.
  static Duration esperaCreciente(int intento) =>
      Duration(seconds: min(60, 1 << min(intento, 6)));

  void iniciar() {
    if (_cerrado || _conexion != null) return;
    unawaited(_conectar());
  }

  Future<void> _conectar() async {
    final token = obtenerToken();
    if (token == null || _cerrado) {
      estado.value = EstadoCanal.detenido;
      return;
    }
    estado.value = EstadoCanal.conectando;
    try {
      final conexion = await conectar(url);
      if (_cerrado) {
        await conexion.cerrar();
        return;
      }
      _conexion = conexion;
      _suscripcion = conexion.tramas.listen(
        _alRecibir,
        onDone: () => _alCerrarse(conexion.codigoCierre),
        onError: (Object _) => _alCerrarse(null),
        cancelOnError: true,
      );
      conexion.enviar(jsonEncode({'type': 'auth', 'token': token}));
    } on Object {
      _programarReintento();
    }
  }

  void _alRecibir(dynamic trama) {
    if (trama is! String) return;
    final Object? json;
    try {
      json = jsonDecode(trama);
    } on FormatException {
      return;
    }
    if (json is! Map<String, dynamic>) return;
    final mensaje = MensajeTiempoReal.desdeJson(json);
    if (mensaje == null) return;
    if (mensaje.tipo == MensajeTiempoReal.autenticacionAceptada) {
      _intentos = 0;
      estado.value = EstadoCanal.conectado;
      return;
    }
    if (!_avisos.isClosed) _avisos.add(mensaje);
  }

  void _alCerrarse(int? codigo) {
    _conexion = null;
    _suscripcion = null;
    if (_cerrado) return;
    if (codigo != null && codigo >= 4000 && codigo <= 4003) {
      // El contrato pide no reintentar con el mismo token.
      estado.value = EstadoCanal.detenido;
      if (codigo == 4001) alTokenInvalido?.call();
      return;
    }
    _programarReintento();
  }

  void _programarReintento() {
    if (_cerrado) return;
    estado.value = EstadoCanal.desconectado;
    _reintento?.cancel();
    _reintento = Timer(_espera(_intentos++), () => unawaited(_conectar()));
  }

  Future<void> cerrar() async {
    _cerrado = true;
    _reintento?.cancel();
    // [estado] no se libera: la pantalla puede seguir escuchándolo un cuadro
    // más mientras Riverpod crea el canal de la nueva sesión.
    estado.value = EstadoCanal.detenido;
    final conexion = _conexion;
    _conexion = null;
    unawaited(_suscripcion?.cancel());
    _suscripcion = null;
    await conexion?.cerrar();
    await _avisos.close();
  }
}

/// `ws://` o `wss://` a partir de la URL del API Gateway (con su `/api`).
Uri urlTiempoReal(String apiBaseUrl) {
  final base = Uri.parse(apiBaseUrl);
  final ruta = base.path.endsWith('/') ? base.path : '${base.path}/';
  return base.replace(
    scheme: base.scheme == 'https' ? 'wss' : 'ws',
    path: '${ruta}v1/realtime',
  );
}

class _ConexionIo implements ConexionWs {
  _ConexionIo(this._ws);

  final WebSocket _ws;

  @override
  Stream<dynamic> get tramas => _ws;

  @override
  void enviar(String trama) => _ws.add(trama);

  @override
  int? get codigoCierre => _ws.closeCode;

  @override
  Future<void> cerrar() => _ws.close();
}

/// Conexión real con la misma configuración de red que el cliente HTTP:
/// cabecera `Host` y certificado fijado de QA (R9).
Future<ConexionWs> conectarConDartIo(Uri url, AppConfig config) async {
  HttpClient? cliente;
  if (config.certificadoSha256.isNotEmpty) {
    final huella = normalizarHuella(config.certificadoSha256);
    cliente = HttpClient()
      ..badCertificateCallback = (certificado, _, _) =>
          certificadoCoincide(certificado.der, huella);
  }
  final ws = await WebSocket.connect(
    url.toString(),
    headers: {if (config.hostHeader.isNotEmpty) 'Host': config.hostHeader},
    customClient: cliente,
  );
  return _ConexionIo(ws);
}

final conectorWsProvider = Provider<ConectorWs>((ref) {
  final config = ref.watch(appConfigProvider);
  return (url) => conectarConDartIo(url, config);
});

/// Roles que usan el canal en la app móvil (el resto recibe 4003).
const _rolesDelCanal = {
  RolUsuario.cliente,
  RolUsuario.empresaContacto,
  RolUsuario.tecnico,
};

/// Un canal por sesión mientras alguna pantalla lo escucha.
final canalTiempoRealProvider = Provider.autoDispose<CanalTiempoReal>((ref) {
  final config = ref.watch(appConfigProvider);
  final sesion = ref.watch(controladorSesionProvider).value;
  final canal = CanalTiempoReal(
    url: urlTiempoReal(config.apiBaseUrl),
    obtenerToken: () =>
        sesion != null && _rolesDelCanal.contains(sesion.usuario.rol)
        ? sesion.accessToken
        : null,
    conectar: ref.watch(conectorWsProvider),
    alTokenInvalido: () =>
        ref.read(controladorSesionProvider.notifier).cerrarSesion(),
  );
  ref.onDispose(canal.cerrar);
  canal.iniciar();
  return canal;
});
