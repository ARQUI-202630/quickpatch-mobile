import 'package:dio/dio.dart';

import 'codigo_error.dart';

/// Error de un campo en un `400 VALIDATION_ERROR`.
class ErrorCampo {
  const ErrorCampo(this.campo, this.mensaje);

  final String campo;
  final String mensaje;
}

/// Error de negocio o de red ya traducido desde el formato Problem Details
/// (RFC 9457, DD sección 8.1.1).
class AppException implements Exception {
  const AppException(
    this.codigo, {
    this.status,
    this.detalle,
    this.correlationId,
    this.erroresCampo = const [],
    this.bloqueadaHasta,
  });

  factory AppException.desdeDio(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => const AppException(
        CodigoError.sinConexion,
      ),
      DioExceptionType.badResponse => AppException.desdeRespuesta(
        e.response?.statusCode,
        e.response?.data,
      ),
      _ => const AppException(CodigoError.desconocido),
    };
  }

  factory AppException.desdeRespuesta(int? status, Object? cuerpo) {
    if (cuerpo is! Map<String, dynamic>) {
      return AppException(
        status == 503
            ? CodigoError.serviceUnavailable
            : CodigoError.desconocido,
        status: status,
      );
    }
    final errores = _erroresDeCampo(cuerpo['errors']);
    final bloqueo = cuerpo['lockedUntil'] as String?;
    final codigo = cuerpo['code'] is String
        ? CodigoError.desdeCodigo(cuerpo['code'] as String)
        : CodigoError.desdeTipo(cuerpo['type'] as String?);
    return AppException(
      codigo,
      status: status,
      detalle: cuerpo['detail'] as String?,
      correlationId: cuerpo['correlationId'] as String?,
      erroresCampo: errores,
      bloqueadaHasta: bloqueo == null ? null : DateTime.parse(bloqueo),
    );
  }

  /// `errors` llega como mapa campo → mensajes (contrato v1) o como lista de
  /// `{field, message}` (propuesta P-07 del DD).
  static List<ErrorCampo> _erroresDeCampo(Object? errores) {
    if (errores is Map<String, dynamic>) {
      return [
        for (final entrada in errores.entries)
          for (final mensaje in (entrada.value as List<dynamic>).cast<String>())
            ErrorCampo(entrada.key, mensaje),
      ];
    }
    if (errores is List<dynamic>) {
      return errores
          .whereType<Map<String, dynamic>>()
          .map((e) => ErrorCampo(e['field'] as String, e['message'] as String))
          .toList();
    }
    return const [];
  }

  final CodigoError codigo;
  final int? status;
  final String? detalle;

  /// Se muestra en soporte para rastrear la petición en los logs (AC7-E4).
  final String? correlationId;
  final List<ErrorCampo> erroresCampo;

  /// Solo en `423 ACCOUNT_LOCKED`.
  final DateTime? bloqueadaHasta;

  String get mensaje => codigo.mensaje;

  /// Mensaje del campo [campo] en un error de validación, si lo hay.
  String? errorDe(String campo) {
    for (final e in erroresCampo) {
      if (e.campo == campo) return e.mensaje;
    }
    return null;
  }

  @override
  String toString() => 'AppException(${codigo.codigo}, status: $status)';
}
