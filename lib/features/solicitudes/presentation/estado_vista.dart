import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../domain/modelos.dart';

/// Cómo se presenta cada estado de la solicitud (DD 7.4): ícono, tono y una
/// frase para el cliente. La reutilizan el detalle y, después, las listas.
class EstadoVista {
  const EstadoVista(this.icono, this.tono, this.descripcion);

  final IconData icono;
  final TonoEstado tono;
  final String descripcion;

  /// Color del texto o ícono y su fondo, según el tema actual.
  (Color, Color) colores(QpEstados estados) => switch (tono) {
    TonoEstado.info => (estados.info, estados.infoFondo),
    TonoEstado.aviso => (estados.aviso, estados.avisoFondo),
    TonoEstado.exito => (estados.exito, estados.exitoFondo),
    TonoEstado.peligro => (estados.peligro, estados.peligroFondo),
  };
}

enum TonoEstado { info, aviso, exito, peligro }

EstadoVista vistaDe(EstadoSolicitud estado) => switch (estado) {
  EstadoSolicitud.buscandoTecnico => const EstadoVista(
    Icons.travel_explore_rounded,
    TonoEstado.info,
    'Estamos buscando un técnico disponible cerca de ti.',
  ),
  EstadoSolicitud.enEspera => const EstadoVista(
    Icons.hourglass_top_rounded,
    TonoEstado.aviso,
    'Por ahora no hay técnicos disponibles; seguimos intentando.',
  ),
  EstadoSolicitud.asignado => const EstadoVista(
    Icons.person_pin_circle_outlined,
    TonoEstado.exito,
    'Un técnico aceptó tu solicitud.',
  ),
  EstadoSolicitud.cotizado => const EstadoVista(
    Icons.request_quote_outlined,
    TonoEstado.aviso,
    'El técnico envió una cotización para que la revises.',
  ),
  EstadoSolicitud.cotizacionAceptada => const EstadoVista(
    Icons.thumb_up_alt_outlined,
    TonoEstado.exito,
    'Aceptaste la cotización.',
  ),
  EstadoSolicitud.enProgreso => const EstadoVista(
    Icons.construction_rounded,
    TonoEstado.info,
    'El técnico está trabajando en tu servicio.',
  ),
  EstadoSolicitud.completado => const EstadoVista(
    Icons.task_alt_rounded,
    TonoEstado.exito,
    'El técnico marcó el servicio como terminado.',
  ),
  EstadoSolicitud.pagado => const EstadoVista(
    Icons.paid_outlined,
    TonoEstado.exito,
    'El servicio está pagado.',
  ),
  EstadoSolicitud.cancelado => const EstadoVista(
    Icons.cancel_outlined,
    TonoEstado.peligro,
    'La solicitud se canceló.',
  ),
};
