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
