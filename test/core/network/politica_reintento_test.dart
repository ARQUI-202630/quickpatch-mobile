import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/core/errors/app_exception.dart';
import 'package:quickpatch_mobile/core/errors/codigo_error.dart';
import 'package:quickpatch_mobile/core/network/politica_reintento.dart';

/// Política de reintentos de la app: solo red y 5xx, máximo 3 veces.
void main() {
  const sinConexion = AppException(CodigoError.sinConexion);
  const caido = AppException(CodigoError.serviceUnavailable, status: 503);
  const interno = AppException(CodigoError.desconocido, status: 500);

  test('reintenta sin conexión y los 5xx con espera creciente', () {
    for (final error in [sinConexion, caido, interno]) {
      expect(politicaReintento(0, error), const Duration(milliseconds: 200));
      expect(politicaReintento(1, error), const Duration(milliseconds: 400));
      expect(politicaReintento(2, error), const Duration(milliseconds: 800));
      expect(politicaReintento(3, error), isNull, reason: 'máximo 3');
    }
  });

  test('no reintenta los 4xx ni otros errores', () {
    for (final error in <Object>[
      const AppException(CodigoError.validationError, status: 400),
      const AppException(CodigoError.unauthenticated, status: 401),
      const AppException(CodigoError.forbidden, status: 403),
      const AppException(CodigoError.notFound, status: 404),
      const AppException(CodigoError.desconocido),
      const FormatException('json'),
      StateError('x'),
    ]) {
      expect(politicaReintento(0, error), isNull, reason: '$error');
    }
  });

  Future<int> llamadasCon(Object error) async {
    var llamadas = 0;
    final provider = FutureProvider<int>((ref) {
      llamadas++;
      throw error;
    });
    final container = ProviderContainer(retry: politicaReintento);
    addTearDown(container.dispose);
    container.listen(provider, (_, _) {});
    // Las tres esperas suman 1,4 s.
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    return llamadas;
  }

  test('con un provider real, un 5xx se intenta 4 veces en total', () async {
    expect(await llamadasCon(caido), 4);
  });

  test('con un provider real, un 404 se intenta una sola vez', () async {
    expect(
      await llamadasCon(const AppException(CodigoError.notFound, status: 404)),
      1,
    );
  });
}
