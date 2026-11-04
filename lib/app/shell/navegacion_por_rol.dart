import 'package:flutter/material.dart';

import '../../core/session/rol_usuario.dart';
import '../router/rutas.dart';

/// Pestaña de la barra de navegación inferior.
class DestinoPrincipal {
  const DestinoPrincipal({
    required this.etiqueta,
    required this.icono,
    required this.iconoActivo,
    required this.ruta,
  });

  final String etiqueta;
  final IconData icono;
  final IconData iconoActivo;
  final String ruta;
}

const _inicio = DestinoPrincipal(
  etiqueta: 'Inicio',
  icono: Icons.home_outlined,
  iconoActivo: Icons.home_rounded,
  ruta: Rutas.inicio,
);

const _cuenta = DestinoPrincipal(
  etiqueta: 'Cuenta',
  icono: Icons.person_outline_rounded,
  iconoActivo: Icons.person_rounded,
  ruta: Rutas.cuenta,
);

/// Pestañas de cada rol (SCRUM-441). La del medio es el trabajo propio del
/// rol: las solicitudes del cliente, las ofertas del técnico o el equipo del
/// proveedor. La administración no usa la app (panel web), así que no tiene.
List<DestinoPrincipal> destinosPara(RolUsuario rol) => switch (rol) {
  RolUsuario.cliente || RolUsuario.empresaContacto => const [
    _inicio,
    DestinoPrincipal(
      etiqueta: 'Solicitudes',
      icono: Icons.receipt_long_outlined,
      iconoActivo: Icons.receipt_long_rounded,
      ruta: Rutas.actividad,
    ),
    _cuenta,
  ],
  RolUsuario.tecnico => const [
    _inicio,
    DestinoPrincipal(
      etiqueta: 'Servicios',
      icono: Icons.work_outline_rounded,
      iconoActivo: Icons.work_rounded,
      ruta: Rutas.actividad,
    ),
    _cuenta,
  ],
  RolUsuario.proveedor => const [
    _inicio,
    DestinoPrincipal(
      etiqueta: 'Equipo',
      icono: Icons.groups_outlined,
      iconoActivo: Icons.groups_rounded,
      ruta: Rutas.actividad,
    ),
    _cuenta,
  ],
  RolUsuario.adminTenant || RolUsuario.adminPlataforma => const [],
};

/// Índice de la pestaña activa para [ubicacion], o `null` si no es una.
int? indiceDestino(List<DestinoPrincipal> destinos, String ubicacion) {
  final indice = destinos.indexWhere((d) => d.ruta == ubicacion);
  return indice < 0 ? null : indice;
}
