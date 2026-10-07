import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'sesion.dart';

/// Almacenamiento clave-valor cifrado. Se abstrae para poder probar sin
/// dispositivo.
abstract interface class AlmacenSeguro {
  Future<String?> leer(String clave);
  Future<void> escribir(String clave, String valor);
  Future<void> borrar(String clave);
}

/// Implementación con Keychain (iOS) y Keystore (Android).
class AlmacenSeguroDispositivo implements AlmacenSeguro {
  const AlmacenSeguroDispositivo([
    this._storage = const FlutterSecureStorage(),
  ]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> leer(String clave) => _storage.read(key: clave);

  @override
  Future<void> escribir(String clave, String valor) =>
      _storage.write(key: clave, value: valor);

  @override
  Future<void> borrar(String clave) => _storage.delete(key: clave);
}

/// Guarda la sesión cifrada y mantiene una copia en memoria para que los
/// interceptores lean el token sin esperar al almacenamiento.
class AlmacenSesion {
  AlmacenSesion(this._almacen);

  static const _clave = 'quickpatch.sesion';

  final AlmacenSeguro _almacen;
  Sesion? _actual;

  Sesion? get actual => _actual;

  Future<Sesion?> cargar() async {
    final texto = await _almacen.leer(_clave);
    if (texto == null) return _actual = null;
    try {
      return _actual = Sesion.fromJson(
        jsonDecode(texto) as Map<String, dynamic>,
      );
    } on Object {
      // Un formato viejo o dañado no debe impedir abrir la app.
      await borrar();
      return null;
    }
  }

  Future<void> guardar(Sesion sesion) async {
    _actual = sesion;
    await _almacen.escribir(_clave, jsonEncode(sesion.toJson()));
  }

  Future<void> borrar() async {
    _actual = null;
    await _almacen.borrar(_clave);
  }
}

final almacenSeguroProvider = Provider<AlmacenSeguro>(
  (ref) => const AlmacenSeguroDispositivo(),
);

final almacenSesionProvider = Provider<AlmacenSesion>(
  (ref) => AlmacenSesion(ref.watch(almacenSeguroProvider)),
);
