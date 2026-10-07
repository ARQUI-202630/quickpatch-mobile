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

/// Implementación con el GPS del dispositivo (paquete `geolocator`).
class ProveedorUbicacionGps implements ProveedorUbicacion {
  const ProveedorUbicacionGps();

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
    final posicion = await Geolocator.getCurrentPosition();
    return Ubicacion(posicion.latitude, posicion.longitude);
  }
}

final proveedorUbicacionProvider = Provider<ProveedorUbicacion>(
  (ref) => const ProveedorUbicacionGps(),
);
