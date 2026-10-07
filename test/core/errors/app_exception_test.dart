import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/core/errors/app_exception.dart';
import 'package:quickpatch_mobile/core/errors/codigo_error.dart';

void main() {
  final peticion = RequestOptions(path: '/v1/x');

  DioException conRespuesta(int status, Object? cuerpo) => DioException(
    requestOptions: peticion,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: peticion,
      statusCode: status,
      data: cuerpo,
    ),
  );

  test('traduce Problem Details con errores de campo', () {
    final e = AppException.desdeDio(
      conRespuesta(400, {
        'status': 400,
        'code': 'VALIDATION_ERROR',
        'detail': 'Faltan campos',
        'correlationId': 'c-1',
        'errors': [
          {'field': 'description', 'message': 'Es obligatorio.'},
        ],
      }),
    );
    expect(e.codigo, CodigoError.validationError);
    expect(e.status, 400);
    expect(e.detalle, 'Faltan campos');
    expect(e.correlationId, 'c-1');
    expect(e.errorDe('description'), 'Es obligatorio.');
    expect(e.errorDe('otro'), isNull);
    expect(e.mensaje, CodigoError.validationError.mensaje);
    expect(e.toString(), contains('VALIDATION_ERROR'));
  });

  test('lee lockedUntil en ACCOUNT_LOCKED', () {
    final e = AppException.desdeDio(
      conRespuesta(423, {
        'code': 'ACCOUNT_LOCKED',
        'lockedUntil': '2026-10-03T15:20:00Z',
      }),
    );
    expect(e.codigo, CodigoError.accountLocked);
    expect(e.bloqueadaHasta, DateTime.utc(2026, 10, 3, 15, 20));
  });

  test('cuerpo sin JSON: 503 es servicio no disponible, otro desconocido', () {
    expect(
      AppException.desdeDio(conRespuesta(503, 'html')).codigo,
      CodigoError.serviceUnavailable,
    );
    expect(
      AppException.desdeDio(conRespuesta(500, null)).codigo,
      CodigoError.desconocido,
    );
  });

  test('errores de red se muestran como sin conexión', () {
    for (final tipo in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ]) {
      final e = AppException.desdeDio(
        DioException(requestOptions: peticion, type: tipo),
      );
      expect(e.codigo, CodigoError.sinConexion, reason: tipo.name);
    }
    expect(
      AppException.desdeDio(
        DioException(requestOptions: peticion, type: DioExceptionType.cancel),
      ).codigo,
      CodigoError.desconocido,
    );
  });

  test('cada código del DD tiene mensaje y se reconoce', () {
    for (final c in CodigoError.values) {
      expect(c.mensaje, isNotEmpty);
      expect(CodigoError.desdeCodigo(c.codigo), c);
    }
    expect(CodigoError.desdeCodigo('NO_EXISTE'), CodigoError.desconocido);
  });

  test('traduce el formato de los contratos v1: type y errores como mapa', () {
    final e = AppException.desdeRespuesta(400, {
      'type': 'https://quickpatch.internal/problems/validacion',
      'status': 400,
      'correlationId': 'c-1',
      'errors': {
        'email': ['No es un correo válido.'],
        'password': ['Muy corta.', 'Sin números.'],
      },
    });

    expect(e.codigo, CodigoError.validationError);
    expect(e.correlationId, 'c-1');
    expect(e.errorDe('email'), 'No es un correo válido.');
    expect(e.erroresCampo, hasLength(3));
  });

  test('cada type de los contratos v1 tiene su código', () {
    const casos = {
      'credenciales-invalidas': CodigoError.invalidCredentials,
      'cuenta-bloqueada': CodigoError.accountLocked,
      'tenant-inactivo': CodigoError.tenantInactive,
      'correo-registrado': CodigoError.duplicateResource,
      'documento-registrado': CodigoError.duplicateResource,
      'categoria-no-disponible': CodigoError.categoryUnavailable,
      'ubicacion-fuera-de-cobertura': CodigoError.locationOutOfCoverage,
      'no-autenticado': CodigoError.unauthenticated,
      'no-autorizado': CodigoError.forbidden,
      'no-encontrado': CodigoError.notFound,
      'canal-sin-tenant': CodigoError.serviceUnavailable,
    };
    for (final MapEntry(:key, :value) in casos.entries) {
      expect(
        CodigoError.desdeTipo('https://quickpatch.internal/problems/$key'),
        value,
      );
    }
    expect(CodigoError.desdeTipo(null), CodigoError.desconocido);
    expect(CodigoError.desdeTipo('otro'), CodigoError.desconocido);
  });
}
