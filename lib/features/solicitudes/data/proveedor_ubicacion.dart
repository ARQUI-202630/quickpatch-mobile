import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/modelos.dart';

/// No se pudo obtener la ubicación del dispositivo.
class UbicacionNoDisponible implements Exception {
  const UbicacionNoDisponible(this.mensaje);

  final String mensaje;
}

/// Ubicación actual del dispositivo. Es una interfaz para poder probar la
/// pantalla sin GPS.
abstract interface class ProveedorUbicacion {
  Future<Ubicacion> actual();
}

/// Tiempo máximo de espera de cada lectura: sin límite, la pantalla quedaría
/// esperando para siempre si el GPS no entrega una posición nueva.
const limiteLectura = Duration(seconds: 15);

/// Antigüedad máxima aceptada para la última posición conocida.
const antiguedadMaxima = Duration(minutes: 10);

/// Lecturas del GPS que usa el respaldo. Se inyectan para probarlo sin el
/// plugin.
class LecturasGps {
  const LecturasGps({
    this.actual = _actualConGeolocator,
    this.ultimaConocida = _ultimaConGeolocator,
    this.ahora = DateTime.now,
  });

  /// Posición nueva; con [soloGpsDelSistema] evita los servicios de Google.
  final Future<Position> Function({bool soloGpsDelSistema}) actual;

  /// Última posición del GPS del sistema, o `null` si no hay.
  final Future<Position?> Function() ultimaConocida;

  final DateTime Function() ahora;
}

Future<Position> _actualConGeolocator({bool soloGpsDelSistema = false}) =>
    Geolocator.getCurrentPosition(
      locationSettings: defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              forceLocationManager: soloGpsDelSistema,
              timeLimit: limiteLectura,
            )
          : const LocationSettings(timeLimit: limiteLectura),
    );

Future<Position?> _ultimaConGeolocator() =>
    Geolocator.getLastKnownPosition(forceAndroidLocationManager: true);

/// Implementación con el GPS del dispositivo (paquete `geolocator`).
///
/// En Android el proveedor por defecto usa los servicios de ubicación de
/// Google, que pueden pedir el permiso de "Location Accuracy". Si el usuario
/// lo rechaza, o el teléfono no tiene esos servicios, se usa el GPS del
/// sistema (`LocationManager`), que no lo necesita.
class ProveedorUbicacionGps implements ProveedorUbicacion {
  const ProveedorUbicacionGps({this.lecturas = const LecturasGps()});

  final LecturasGps lecturas;

  @override
  Future<Ubicacion> actual() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const UbicacionNoDisponible(
        'Activa la ubicación del teléfono para continuar.',
      );
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      throw const UbicacionNoDisponible(
        'Necesitamos tu ubicación para buscar técnicos cercanos.',
      );
    }
    final posicion = await leerConRespaldo(lecturas);
    return Ubicacion(posicion.latitude, posicion.longitude);
  }
}

/// Intenta con el proveedor por defecto; si falla, usa la última posición
/// reciente del GPS del sistema o una lectura nueva de ese GPS. Si nada
/// funciona, lanza [UbicacionNoDisponible] con un mensaje claro.
@visibleForTesting
Future<Position> leerConRespaldo(LecturasGps lecturas) async {
  try {
    return await lecturas.actual();
  } on Exception {
    try {
      final ultima = await lecturas.ultimaConocida();
      if (ultima != null &&
          lecturas.ahora().difference(ultima.timestamp) <= antiguedadMaxima) {
        return ultima;
      }
      return await lecturas.actual(soloGpsDelSistema: true);
    } on Exception {
      throw const UbicacionNoDisponible(
        'No pudimos obtener tu ubicación. Revisa que el GPS esté activo e '
        'inténtalo de nuevo.',
      );
    }
  }
}

final proveedorUbicacionProvider = Provider<ProveedorUbicacion>(
  (ref) => const ProveedorUbicacionGps(),
);
