// Validaciones de formularios compartidas por varias pantallas.

/// Valida el correo antes de enviarlo (AC4, protección ante errores).
String? validarEmail(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return 'Escribe tu correo.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texto)) {
    return 'Escribe un correo válido, por ejemplo ana@correo.com.';
  }
  return null;
}

/// Mismos límites que el contrato: entre 8 y 128 caracteres.
String? validarContrasena(String? valor) {
  final texto = valor ?? '';
  if (texto.length < 8) return 'Usa al menos 8 caracteres.';
  if (texto.length > 128) return 'Máximo 128 caracteres.';
  return null;
}

/// NIT de una empresa cliente: de 5 a 15 dígitos y, opcionalmente, el dígito
/// de verificación (`900123456-7`), como pide `CompanyData.nit` (identity
/// 1.8.0). Sin puntos ni espacios.
String? validarNit(String? valor) {
  final nit = valor?.trim() ?? '';
  if (nit.isEmpty) return 'Es obligatorio.';
  if (!RegExp(r'^[0-9]{5,15}(-[0-9])?$').hasMatch(nit)) {
    return 'Escribe solo números y, si quieres, el dígito de verificación '
        '(900123456-7).';
  }
  return null;
}
