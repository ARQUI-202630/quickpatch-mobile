import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/cliente_api.dart';
import '../domain/mensaje_chat.dart';

/// Chat de una solicitud entre el cliente y el técnico asignado
/// (`communication.v1.yaml` 1.3.0, ADR-026). Solo los dos participantes lo
/// ven: para cualquier otro usuario la API responde 404.
class RepositorioChat {
  const RepositorioChat(this._dio);

  final Dio _dio;

  static const tamanoPagina = 30;

  /// Mensajes del más reciente al más antiguo.
  Future<PaginaChat> listar(String solicitudId, {int pagina = 1}) =>
      _llamar(() async {
        final respuesta = await _dio.get<Map<String, dynamic>>(
          ApiEndpoints.mensajesChat(solicitudId),
          queryParameters: {'page': pagina, 'size': tamanoPagina},
        );
        return PaginaChat.desdeJson(respuesta.data!);
      });

  /// Envía [texto]; la API le quita los espacios de los extremos. Con la
  /// solicitud cerrada responde 409 `chat-cerrado`, y sin técnico asignado,
  /// 409 `chat-no-disponible`.
  Future<MensajeChat> enviar(String solicitudId, String texto) =>
      _llamar(() async {
        final respuesta = await _dio.post<Map<String, dynamic>>(
          ApiEndpoints.mensajesChat(solicitudId),
          data: {'text': texto},
        );
        return MensajeChat.desdeJson(respuesta.data!);
      });

  Future<T> _llamar<T>(Future<T> Function() llamada) async {
    try {
      return await llamada();
    } on DioException catch (e) {
      throw AppException.desdeDio(e);
    }
  }
}

final repositorioChatProvider = Provider<RepositorioChat>(
  (ref) => RepositorioChat(ref.watch(clienteApiProvider)),
);
