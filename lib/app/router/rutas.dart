/// Rutas de la app. Cada feature agrega aquí las suyas.
abstract final class Rutas {
  static const cargando = '/cargando';
  static const iniciarSesion = '/iniciar-sesion';
  static const registro = '/registro';
  static const registroTecnico = '/registro/tecnico';

  /// Activación de un técnico del equipo de un proveedor (SCRUM-98). Es la
  /// ruta del enlace de invitación (`/activar#token=...`), así que no cambia.
  static const activarCuenta = '/activar';

  // Pestañas de la barra inferior (SCRUM-441).
  static const inicio = '/inicio';
  static const actividad = '/actividad';
  static const cuenta = '/cuenta';

  /// Buzón de notificaciones (SCRUM-459).
  static const notificaciones = '/notificaciones';

  static const disponibilidad = '/tecnico/disponibilidad';

  /// Detalle de la solicitud asignada, para el técnico (SCRUM-92).
  static const solicitudAsignadaPatron = '/tecnico/solicitudes/:id';
  static String solicitudAsignada(String id) => '/tecnico/solicitudes/$id';

  static const altaTecnico = '/equipo/nuevo';

  static const nuevaSolicitud = '/solicitudes/nueva';
  static const detalleSolicitudPatron = '/solicitudes/:id';
  static String detalleSolicitud(String id) => '/solicitudes/$id';

  /// Nueva solicitud con la categoría ya elegida desde el inicio.
  static String nuevaSolicitudEn(String categoriaId) => Uri(
    path: nuevaSolicitud,
    queryParameters: {'categoria': categoriaId},
  ).toString();
}
