/// Rutas REST que consume la app móvil.
///
/// Fuente: `quickpatch-contracts/openapi/` (identity 1.1.0, catalog 1.0.0 y
/// service-request 1.0.0). Las rutas marcadas "pendiente de contrato" vienen
/// del catálogo del DD 3.1 y todavía no tienen especificación publicada: no
/// deben usarse hasta que exista. No agregar rutas que no estén en el DD.
abstract final class ApiEndpoints {
  // Identity Service
  static const registroCliente = '/v1/auth/register/client';
  static const registroTecnico = '/v1/auth/register/technician';
  static const login = '/v1/auth/login';
  static const usuarioActual = '/v1/users/me';

  // Pendientes de contrato (DD 3.1).
  static const registroEmpresa = '/v1/auth/register/company';
  static const refresh = '/v1/auth/refresh';
  static const usuariosEmpresa = '/v1/companies/me/users';
  static const equipoProveedor = '/v1/providers/me/technicians';

  // Catalog Service
  static const categorias = '/v1/catalog/categories';

  // Matching Service
  static const localidades = '/v1/localities';
  static const disponibilidad = '/v1/technicians/me/availability';
  static const cobertura = '/v1/technicians/me/coverage';
  static const ofertas = '/v1/matching/offers';
  static String aceptarOferta(String attemptId) =>
      '/v1/matching/offers/$attemptId/accept';
  static String rechazarOferta(String attemptId) =>
      '/v1/matching/offers/$attemptId/reject';

  // ServiceRequest Service
  static const solicitudes = '/v1/service-requests';
  static String solicitud(String id) => '/v1/service-requests/$id';
  static String cancelar(String id) => '/v1/service-requests/$id/cancel';
  static String cotizaciones(String id) => '/v1/service-requests/$id/quotes';
  static String aceptarCotizacion(String id, String quoteId) =>
      '/v1/service-requests/$id/quotes/$quoteId/accept';
  static String rechazarCotizacion(String id, String quoteId) =>
      '/v1/service-requests/$id/quotes/$quoteId/reject';
  static String iniciar(String id) => '/v1/service-requests/$id/start';
  static String evidencias(String id) => '/v1/service-requests/$id/evidence';
  static String archivoEvidencia(String id, String evidenceId) =>
      '/v1/service-requests/$id/evidence/$evidenceId/file';
  static String completar(String id) => '/v1/service-requests/$id/complete';
  static String calificar(String id) => '/v1/service-requests/$id/rating';
  static const historialTecnico = '/v1/technicians/me/service-requests';

  // Payments Service
  static String pago(String id) => '/v1/service-requests/$id/payment';
  static String comprobante(String paymentId) =>
      '/v1/payments/$paymentId/invoice';
  static const pagosRecibidos = '/v1/payments/received';
}
