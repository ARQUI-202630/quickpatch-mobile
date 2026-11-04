import '../errors/app_exception.dart';
import '../errors/codigo_error.dart';

/// Reintentos de los providers que fallan, para toda la app (va en el
/// `ProviderScope` de `main.dart`).
///
/// Mientras Riverpod reintenta, el provider sigue en carga: reintentar un
/// error que no va a cambiar deja la pantalla cargando. Por eso solo se
/// reintentan los errores de red y los 5xx, como máximo [maximoReintentos]
/// veces con espera creciente (0,2 s, 0,4 s y 0,8 s). Los 4xx (403, 404,
/// validación) y cualquier otro error se muestran de una vez.
Duration? politicaReintento(int intento, Object error) {
  if (intento >= maximoReintentos || !esReintentable(error)) return null;
  return esperaInicial * (1 << intento);
}

const maximoReintentos = 3;
const esperaInicial = Duration(milliseconds: 200);

/// Errores que pueden desaparecer solos: sin conexión o 5xx.
bool esReintentable(Object error) {
  if (error is! AppException) return false;
  if (error.codigo == CodigoError.sinConexion) return true;
  final status = error.status;
  return status != null && status >= 500;
}
