/// Rutas de la app. Cada feature agrega aquí las suyas.
abstract final class Rutas {
  static const cargando = '/cargando';
  static const iniciarSesion = '/iniciar-sesion';
  static const registro = '/registro';
  static const registroTecnico = '/registro/tecnico';

  // Pestañas de la barra inferior (SCRUM-441).
  static const inicio = '/inicio';
  static const actividad = '/actividad';
  static const cuenta = '/cuenta';

  static const nuevaSolicitud = '/solicitudes/nueva';
  static const detalleSolicitudPatron = '/solicitudes/:id';
  static String detalleSolicitud(String id) => '/solicitudes/$id';

  /// Nueva solicitud con la categoría ya elegida desde el inicio.
  static String nuevaSolicitudEn(String categoriaId) => Uri(
    path: nuevaSolicitud,
    queryParameters: {'categoria': categoriaId},
  ).toString();
}
