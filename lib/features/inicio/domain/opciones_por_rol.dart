import '../../../app/router/rutas.dart';
import '../../../core/session/rol_usuario.dart';

/// Capacidad que ve un rol en su pantalla de inicio.
class OpcionInicio {
  const OpcionInicio(this.titulo, this.requisito, {this.ruta});

  final String titulo;

  /// Requisito del SRS que la origina.
  final String requisito;

  /// Pantalla de la opción; `null` mientras la feature no esté implementada.
  final String? ruta;

  bool get disponible => ruta != null;

  /// La opción lleva a una pestaña de la barra inferior: se cambia de
  /// pestaña en vez de apilar otra pantalla.
  bool get esPestana => ruta == Rutas.actividad;
}

/// Opciones de cada rol en la app móvil, según la relación pantalla–contrato
/// del DD v3 (trasladada a SCRUM-332). Cada opción se habilita cuando su
/// feature esté implementada.
List<OpcionInicio> opcionesPara(RolUsuario rol) => switch (rol) {
  RolUsuario.cliente => const [
    OpcionInicio('Nueva solicitud', 'RF-07', ruta: Rutas.nuevaSolicitud),
    OpcionInicio('Mis solicitudes', 'RF-11'),
    OpcionInicio('Pagos y comprobantes', 'RF-22'),
  ],
  RolUsuario.empresaContacto => const [
    OpcionInicio('Nueva solicitud', 'RF-08'),
    OpcionInicio('Solicitudes de la empresa', 'RF-11'),
    OpcionInicio('Pagos y comprobantes', 'RF-22'),
    OpcionInicio('Usuarios de la empresa', 'RF-06'),
  ],
  RolUsuario.tecnico => const [
    OpcionInicio(
      'Disponibilidad y cobertura',
      'RF-13',
      ruta: Rutas.disponibilidad,
    ),
    OpcionInicio('Ofertas', 'RF-10'),
    OpcionInicio('Mis servicios', 'RF-17', ruta: Rutas.actividad),
    OpcionInicio('Pagos recibidos', 'RF-25'),
  ],
  RolUsuario.proveedor => const [OpcionInicio('Mi equipo', 'RF-16')],
  RolUsuario.adminTenant || RolUsuario.adminPlataforma => const [],
};
