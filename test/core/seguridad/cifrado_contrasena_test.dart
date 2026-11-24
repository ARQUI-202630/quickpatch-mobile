import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';
import 'package:quickpatch_mobile/core/network/api_endpoints.dart';
import 'package:quickpatch_mobile/core/seguridad/cifrado_contrasena.dart';

import '../../helpers/fakes.dart';

/// Par de llaves RSA de 2048 bits para la prueba.
AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _parDeLlaves() {
  final semilla = Random(7);
  final aleatorio = FortunaRandom()
    ..seed(
      KeyParameter(
        Uint8List.fromList(List.generate(32, (_) => semilla.nextInt(256))),
      ),
    );
  final generador = RSAKeyGenerator()
    ..init(
      ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
        aleatorio,
      ),
    );
  final par = generador.generateKeyPair();
  return AsymmetricKeyPair(par.publicKey, par.privateKey);
}

/// La llave pública en SubjectPublicKeyInfo (DER) y base64, como la publica
/// Identity.
String _spki(RSAPublicKey llave) {
  final algoritmo = ASN1Sequence(
    elements: [ASN1ObjectIdentifier.fromName('rsaEncryption'), ASN1Null()],
  );
  final rsa = ASN1Sequence(
    elements: [ASN1Integer(llave.modulus), ASN1Integer(llave.exponent)],
  );
  final spki = ASN1Sequence(
    elements: [
      algoritmo,
      ASN1BitString(stringValues: rsa.encode()),
    ],
  );
  return base64.encode(spki.encode());
}

String _descifrar(RSAPrivateKey privada, String ciphertext) {
  final relleno = '=' * ((4 - ciphertext.length % 4) % 4);
  final descifrador = OAEPEncoding.withSHA256(RSAEngine())
    ..init(false, PrivateKeyParameter<RSAPrivateKey>(privada));
  return utf8.decode(
    descifrador.process(base64Url.decode(ciphertext + relleno)),
  );
}

void main() {
  final par = _parDeLlaves();
  late List<RequestOptions> peticiones;
  late String keyIdVigente;
  late bool primeraVezLlaveVieja;

  Dio dio(ResponseBody Function(RequestOptions) responder) =>
      Dio(BaseOptions(baseUrl: 'https://gw/api'))
        ..httpClientAdapter = AdaptadorFalso((o) {
          peticiones.add(o);
          return responder(o);
        });

  ResponseBody llave(RequestOptions o) => respuestaJson({
    'keyId': keyIdVigente,
    'algorithm': 'RSA-OAEP-256',
    'publicKey': _spki(par.publicKey),
  }, 200);

  setUp(() {
    peticiones = [];
    keyIdVigente = 'llave-1';
    primeraVezLlaveVieja = false;
  });

  Future<void> enviarLogin(CifradoRsa cifrado, Dio cliente, String clave) =>
      cifrado.enviar(
        clave,
        (cifrada) => cliente.post<void>(
          ApiEndpoints.login,
          data: {'email': 'ana@correo.co', 'encryptedPassword': cifrada},
        ),
      );

  test(
    'cifra con la llave pública y nunca manda la contraseña en claro',
    () async {
      final cliente = dio(
        (o) => o.path == ApiEndpoints.llaveContrasena
            ? llave(o)
            : respuestaJson({}, 200),
      );
      await enviarLogin(CifradoRsa(cliente), cliente, 'Clave.ñ2026');

      final login = peticiones.last;
      final cifrada = (login.data as Map)['encryptedPassword'] as Map;
      expect((login.data as Map).containsKey('password'), isFalse);
      expect(cifrada['keyId'], 'llave-1');
      expect(cifrada['ciphertext'], isNot(contains('Clave')));
      expect(
        _descifrar(par.privateKey, cifrada['ciphertext'] as String),
        'Clave.ñ2026',
      );
    },
  );

  test('pide la llave una sola vez para varios envíos', () async {
    final cliente = dio(
      (o) => o.path == ApiEndpoints.llaveContrasena
          ? llave(o)
          : respuestaJson({}, 200),
    );
    final cifrado = CifradoRsa(cliente);
    await enviarLogin(cifrado, cliente, 'Uno.2026');
    await enviarLogin(cifrado, cliente, 'Dos.2026');

    expect(
      peticiones.where((o) => o.path == ApiEndpoints.llaveContrasena),
      hasLength(1),
    );
  });

  test(
    'con llave-desconocida pide la llave de nuevo y reintenta una vez',
    () async {
      final cliente = dio((o) {
        if (o.path == ApiEndpoints.llaveContrasena) return llave(o);
        final keyId = ((o.data as Map)['encryptedPassword'] as Map)['keyId'];
        if (keyId == 'llave-1' && !primeraVezLlaveVieja) {
          primeraVezLlaveVieja = true;
          keyIdVigente = 'llave-2';
          return respuestaJson({
            'type': 'https://quickpatch.internal/problems/llave-desconocida',
            'status': 400,
          }, 400);
        }
        return respuestaJson({}, 200);
      });

      await enviarLogin(CifradoRsa(cliente), cliente, 'Clave.2026');

      final logins = peticiones.where((o) => o.path == ApiEndpoints.login);
      expect(logins, hasLength(2));
      expect(
        ((logins.last.data as Map)['encryptedPassword'] as Map)['keyId'],
        'llave-2',
      );
    },
  );

  test('otros errores no se reintentan', () async {
    final cliente = dio(
      (o) => o.path == ApiEndpoints.llaveContrasena
          ? llave(o)
          : respuestaJson({
              'type':
                  'https://quickpatch.internal/problems/credenciales-invalidas',
              'status': 401,
            }, 401),
    );

    await expectLater(
      enviarLogin(CifradoRsa(cliente), cliente, 'Clave.2026'),
      throwsA(isA<DioException>()),
    );
    expect(peticiones.where((o) => o.path == ApiEndpoints.login), hasLength(1));
  });
}
