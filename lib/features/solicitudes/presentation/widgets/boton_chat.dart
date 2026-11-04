import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../domain/modelos.dart';

/// Abre el chat de la solicitud desde su detalle (SCRUM-482). Solo navega por
/// la ruta: la feature `chat` no se importa desde aquí.
class BotonChat extends StatelessWidget {
  const BotonChat({required this.solicitudId, required this.con, super.key});

  final String solicitudId;

  /// Con quién se habla: "el técnico" o "el cliente".
  final String con;

  /// Hay chat desde que la solicitud tiene técnico asignado; al cerrarse
  /// queda el historial (RN-CH2). Una cancelada lo tiene solo si llegó a
  /// tener técnico.
  static bool aplica(Solicitud s) => switch (s.estado) {
    EstadoSolicitud.buscandoTecnico || EstadoSolicitud.enEspera => false,
    EstadoSolicitud.cancelado => s.tecnicoId != null || s.tecnico != null,
    _ => true,
  };

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const Key('boton-chat'),
    onPressed: () => context.push(Rutas.chatSolicitud(solicitudId)),
    icon: const Icon(Icons.chat_bubble_outline_rounded),
    label: Text('Chat con $con'),
  );
}
