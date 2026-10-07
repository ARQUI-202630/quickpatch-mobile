import '../../../core/session/rol_usuario.dart';

/// Capacidad que ve un rol en su pantalla de inicio.
class OpcionInicio {
  const OpcionInicio(this.titulo, this.requisito);

  final String titulo;

  /// Requisito del SRS que la origina.
  final String requisito;
}

/// Opciones de cada rol en la app móvil, según la relación pantalla–contrato
/// del DD v3 (trasladada a SCRUM-332). Cada opción se habilita cuando su
/// feature esté implementada.
List<OpcionInicio> opcionesPara(RolUsuario rol) => switch (rol) {
  RolUsuario.cliente => const [
    OpcionInicio('Nueva solicitud', 'RF-07'),
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
    OpcionInicio('Disponibilidad y cobertura', 'RF-13'),
    OpcionInicio('Ofertas', 'RF-10'),
    OpcionInicio('Historial de servicios', 'RF-17'),
    OpcionInicio('Pagos recibidos', 'RF-25'),
  ],
  RolUsuario.proveedor => const [OpcionInicio('Mi equipo', 'RF-16')],
  RolUsuario.adminTenant || RolUsuario.adminPlataforma => const [],
};
