/// Mensaje del chat de una solicitud (`ChatMessage`, communication.v1.yaml
/// 1.3.0, ADR-026). Llega igual por REST y en la trama `chat.message`.
class MensajeChat {
  const MensajeChat({
    required this.id,
    required this.autorId,
    required this.rolAutor,
    required this.texto,
    required this.enviadoEn,
  });

  factory MensajeChat.desdeJson(Map<String, dynamic> json) => MensajeChat(
    id: json['id'] as String,
    autorId: json['authorId'] as String,
    rolAutor: json['authorRole'] as String,
    texto: json['text'] as String,
    enviadoEn: DateTime.parse(json['sentAt'] as String),
  );

  /// Igual que [MensajeChat.desdeJson], pero devuelve `null` si a la trama le
  /// falta algún campo: un aviso mal formado no rompe la conversación.
  static MensajeChat? intentar(Map<String, dynamic> json) {
    try {
      return MensajeChat.desdeJson(json);
    } on Object {
      return null;
    }
  }

  final String id;
  final String autorId;

  /// `cliente` o `tecnico`; un `empresa_contacto` dueño escribe como cliente.
  final String rolAutor;
  final String texto;

  /// Hora del servidor al guardarlo.
  final DateTime enviadoEn;
}

/// Página de `GET /v1/service-requests/{id}/messages`: del más reciente al más
/// antiguo, con [escribible] para el usuario del token (RN-CH2).
class PaginaChat {
  const PaginaChat({
    required this.mensajes,
    required this.pagina,
    required this.tamano,
    required this.total,
    required this.escribible,
  });

  factory PaginaChat.desdeJson(Map<String, dynamic> json) => PaginaChat(
    mensajes: (json['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(MensajeChat.desdeJson)
        .toList(),
    pagina: json['page'] as int,
    tamano: json['size'] as int,
    total: json['totalItems'] as int,
    escribible: json['writable'] as bool,
  );

  final List<MensajeChat> mensajes;
  final int pagina;
  final int tamano;
  final int total;
  final bool escribible;

  bool get hayMas => pagina * tamano < total;
}

/// Límites de `SendMessageRequest` (RN-CH4).
abstract final class LimitesChat {
  static const longitudMaxima = 1000;
}
