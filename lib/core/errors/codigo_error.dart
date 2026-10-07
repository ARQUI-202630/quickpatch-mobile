/// Códigos de error de los contratos REST (DD, sección 8.1.1) más dos
/// propios del cliente: [sinConexion] y [desconocido].
enum CodigoError {
  validationError('VALIDATION_ERROR', 'Revisa los campos marcados.'),
  unauthenticated(
    'UNAUTHENTICATED',
    'Tu sesión terminó. Vuelve a iniciar sesión.',
  ),
  invalidCredentials(
    'INVALID_CREDENTIALS',
    'El correo o la contraseña no son correctos.',
  ),
  forbidden('FORBIDDEN', 'No tienes permiso para hacer esta acción.'),
  notFound('NOT_FOUND', 'No encontramos lo que buscas.'),
  invalidStateTransition(
    'INVALID_STATE_TRANSITION',
    'La solicitud cambió de estado. Actualizamos la información.',
  ),
  offerNotAvailable(
    'OFFER_NOT_AVAILABLE',
    'Esta oferta ya no está disponible.',
  ),
  technicianNotAvailable(
    'TECHNICIAN_NOT_AVAILABLE',
    'Ya no estás disponible para aceptar ofertas.',
  ),
  quoteLimitReached(
    'QUOTE_LIMIT_REACHED',
    'La solicitud ya tiene el máximo de 3 cotizaciones.',
  ),
  paymentNotReady(
    'PAYMENT_NOT_READY',
    'El pago todavía no está listo. Intenta en unos segundos.',
  ),
  paymentInProgress('PAYMENT_IN_PROGRESS', 'Ya hay un pago en proceso.'),
  alreadyPaid('ALREADY_PAID', 'Este servicio ya fue pagado.'),
  alreadyRated('ALREADY_RATED', 'Ya calificaste este servicio.'),
  duplicateResource('DUPLICATE_RESOURCE', 'Ese dato ya está registrado.'),
  categoryUnavailable(
    'CATEGORY_UNAVAILABLE',
    'Esa categoría ya no está disponible. Elige otra.',
  ),
  evidenceRequired(
    'EVIDENCE_REQUIRED',
    'Sube al menos una foto de evidencia antes de completar.',
  ),
  locationOutOfCoverage(
    'LOCATION_OUT_OF_COVERAGE',
    'La dirección está fuera de la zona de cobertura (Bogotá).',
  ),
  tenantInactive(
    'TENANT_INACTIVE',
    'El servicio no está disponible en este momento.',
  ),
  accountLocked(
    'ACCOUNT_LOCKED',
    'Tu cuenta está bloqueada temporalmente por intentos fallidos.',
  ),
  paymentProviderError(
    'PAYMENT_PROVIDER_ERROR',
    'La pasarela de pagos no respondió. Revisaremos el estado del pago.',
  ),
  serviceUnavailable(
    'SERVICE_UNAVAILABLE',
    'El servicio no está disponible. Intenta más tarde.',
  ),
  sinConexion('SIN_CONEXION', 'No hay conexión con QUICKPATCH.'),
  desconocido('DESCONOCIDO', 'Ocurrió un error inesperado.');

  const CodigoError(this.codigo, this.mensaje);

  /// Valor de `code` en el Problem Details.
  final String codigo;

  /// Mensaje para el usuario. El frontend elige el mensaje por `code`.
  final String mensaje;

  /// Último segmento de `type` en los contratos v1
  /// (`https://quickpatch.internal/problems/<tipo>`).
  static const _porTipo = {
    'validacion': validationError,
    'no-autenticado': unauthenticated,
    'credenciales-invalidas': invalidCredentials,
    'no-autorizado': forbidden,
    'no-encontrado': notFound,
    'correo-registrado': duplicateResource,
    'documento-registrado': duplicateResource,
    'categoria-no-disponible': categoryUnavailable,
    'ubicacion-fuera-de-cobertura': locationOutOfCoverage,
    'tenant-inactivo': tenantInactive,
    'cuenta-bloqueada': accountLocked,
    'canal-sin-tenant': serviceUnavailable,
  };

  static CodigoError desdeTipo(String? tipo) {
    if (tipo == null) return desconocido;
    return _porTipo[tipo.split('/').last] ?? desconocido;
  }

  static CodigoError desdeCodigo(String? codigo) {
    for (final c in values) {
      if (c.codigo == codigo) return c;
    }
    return desconocido;
  }
}
