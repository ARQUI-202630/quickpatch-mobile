import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

import '../network/api_endpoints.dart';
import '../network/cliente_api.dart';
import '../network/interceptores.dart';

/// Cifra la contraseña antes de enviarla (`identity.v1.yaml` 1.11.0), para
/// que no viaje legible ni dentro de la red del laboratorio, donde VM1 ya
/// terminó el TLS.
abstract interface class CifradoContrasena {
  /// Llama a [enviar] con el `encryptedPassword` (`keyId` y `ciphertext`)
  /// que va en el cuerpo en lugar de `password`.
  Future<T> enviar<T>(
    String password,
    Future<T> Function(Map<String, String> cifrada) enviar,
  );
}

/// RSA-OAEP con SHA-256 y la llave pública de `GET /v1/auth/password-key`.
/// Pide la llave una vez; si Identity responde `llave-desconocida` porque la
/// llave cambió, pide la nueva y reintenta una sola vez.
class CifradoRsa implements CifradoContrasena {
  CifradoRsa(this._dio);

  final Dio _dio;
  Future<_Llave>? _llave;

  @override
  Future<T> enviar<T>(
    String password,
    Future<T> Function(Map<String, String> cifrada) enviar,
  ) async {
    try {
      return await enviar(await _cifrar(password));
    } on DioException catch (e) {
      final cuerpo = e.response?.data;
      final tipo = cuerpo is Map ? cuerpo['type'] : null;
      if (tipo is! String || !tipo.endsWith('/llave-desconocida')) rethrow;
      _llave = null;
      return enviar(await _cifrar(password));
    }
  }

  Future<Map<String, String>> _cifrar(String password) async {
    final llave = await (_llave ??= _pedirLlave().catchError((Object e) {
      _llave = null;
      throw e;
    }));
    return {
      'keyId': llave.keyId,
      'ciphertext': cifrarRsaOaep(llave.publica, password),
    };
  }

  Future<_Llave> _pedirLlave() async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.llaveContrasena,
      options: opcionesPublicas(),
    );
    final datos = respuesta.data!;
    return _Llave(
      datos['keyId'] as String,
      llavePublicaDeSpki(base64.decode(datos['publicKey'] as String)),
    );
  }
}

class _Llave {
  const _Llave(this.keyId, this.publica);

  final String keyId;
  final RSAPublicKey publica;
}

/// Lee una llave pública RSA en SubjectPublicKeyInfo (DER), el formato que
/// publica Identity.
RSAPublicKey llavePublicaDeSpki(Uint8List der) {
  final spki = ASN1Parser(der).nextObject() as ASN1Sequence;
  final bits = spki.elements![1] as ASN1BitString;
  final rsa =
      ASN1Parser(Uint8List.fromList(bits.stringValues!)).nextObject()
          as ASN1Sequence;
  return RSAPublicKey(
    (rsa.elements![0] as ASN1Integer).integer!,
    (rsa.elements![1] as ASN1Integer).integer!,
  );
}

/// Cifra [texto] en UTF-8 con RSA-OAEP y SHA-256, y devuelve base64url sin
/// relleno, como pide el esquema `EncryptedPassword`.
String cifrarRsaOaep(RSAPublicKey llave, String texto) {
  final semilla = Random.secure();
  final aleatorio = FortunaRandom()
    ..seed(
      KeyParameter(
        Uint8List.fromList(List.generate(32, (_) => semilla.nextInt(256))),
      ),
    );
  final cifrador = OAEPEncoding.withSHA256(RSAEngine())
    ..init(
      true,
      ParametersWithRandom(PublicKeyParameter<RSAPublicKey>(llave), aleatorio),
    );
  final cifrado = cifrador.process(Uint8List.fromList(utf8.encode(texto)));
  return base64Url.encode(cifrado).replaceAll('=', '');
}

final cifradoContrasenaProvider = Provider<CifradoContrasena>(
  (ref) => CifradoRsa(ref.watch(clienteApiProvider)),
);
