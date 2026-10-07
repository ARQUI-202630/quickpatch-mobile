import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';
import 'package:quickpatch_mobile/core/session/sesion.dart';

/// Almacenamiento en memoria en lugar de Keychain/Keystore.
class AlmacenSeguroEnMemoria implements AlmacenSeguro {
  final datos = <String, String>{};

  @override
  Future<String?> leer(String clave) async => datos[clave];

  @override
  Future<void> escribir(String clave, String valor) async =>
      datos[clave] = valor;

  @override
  Future<void> borrar(String clave) async => datos.remove(clave);
}

/// Adaptador HTTP que responde lo que la prueba indique y guarda la
/// última petición.
class AdaptadorFalso implements HttpClientAdapter {
  AdaptadorFalso(this.responder);

  ResponseBody Function(RequestOptions opciones) responder;
  RequestOptions? ultima;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    ultima = options;
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody respuestaJson(Object cuerpo, int status) =>
    ResponseBody.fromString(
      jsonEncode(cuerpo),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Respuesta de `POST /v1/auth/login` según `identity.v1.yaml`.
Map<String, dynamic> loginJson({String rol = 'cliente', int expira = 900}) => {
  'accessToken': 'token-acceso',
  'tokenType': 'Bearer',
  'expiresIn': expira,
  'user': {
    'id': 'f1e2d3c4-0000-4a1b-9c8d-111122223333',
    'email': 'ana@correo.co',
    'fullName': 'Ana Gómez',
    'role': rol,
    'phone': null,
    'verificationStatus': null,
  },
};

Sesion sesionDePrueba({
  RolUsuario rol = RolUsuario.cliente,
  DateTime? expiraEn,
}) => Sesion(
  accessToken: 'token-acceso',
  refreshToken: 'token-renovacion',
  expiraEn: expiraEn ?? DateTime.now().toUtc().add(const Duration(hours: 1)),
  usuario: UsuarioSesion(userId: 'u-1', fullName: 'Ana Gómez', rol: rol),
);
