/// Token de la invitación de un técnico del equipo (SCRUM-98, identity
/// 1.7.0). Identity arma el enlace como `https://<host>/activar#token=<token>`:
/// el token va después de `#` para que no llegue a los registros de los
/// servidores web. El técnico puede pegar el enlace completo o solo el token.
///
/// Devuelve `null` si [texto] no trae un token con la forma del contrato
/// (43 caracteres base64url, 256 bits).
String? tokenDeInvitacion(String texto) {
  final limpio = texto.trim();
  if (_token.hasMatch(limpio)) return limpio;
  final enlace = Uri.tryParse(limpio);
  if (enlace == null) return null;
  for (final parte in [enlace.fragment, enlace.query]) {
    final valor = _parametroToken(parte);
    if (valor != null && _token.hasMatch(valor)) return valor;
  }
  return null;
}

final _token = RegExp(r'^[A-Za-z0-9_-]{43}$');

String? _parametroToken(String parametros) {
  if (parametros.isEmpty) return null;
  try {
    return Uri.splitQueryString(parametros)['token'];
  } on FormatException {
    return null;
  }
}
