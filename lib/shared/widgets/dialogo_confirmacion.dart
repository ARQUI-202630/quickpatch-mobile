import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Diálogo de confirmación de la app (SCRUM-638, guía de componentes de la
/// SCRUM-620): título, contenido, «Volver» a la izquierda y la acción a la
/// derecha. Con [peligro], la acción va en el rojo de los estados: rechazar,
/// cancelar o descartar algo que no se puede recuperar.
///
/// Para una pregunta de sí o no basta [confirmar]. Los diálogos que piden un
/// dato y hacen la petición adentro (cancelar la solicitud, rechazar la
/// cotización) usan este widget con [enviando] y [alConfirmar].
class DialogoConfirmacion extends StatelessWidget {
  const DialogoConfirmacion({
    required this.titulo,
    required this.contenido,
    required this.accion,
    required this.alConfirmar,
    this.alVolver,
    this.peligro = false,
    this.volver = 'Volver',
    this.enviando = false,
    this.etiquetaEnviando,
    this.claveConfirmar,
    this.claveVolver,
    super.key,
  });

  final String titulo;
  final Widget contenido;

  /// Texto del botón que confirma, por ejemplo «Rechazar».
  final String accion;
  final VoidCallback alConfirmar;

  /// Por omisión cierra el diálogo sin resultado.
  final VoidCallback? alVolver;
  final bool peligro;

  /// Texto del botón que sale sin hacer nada.
  final String volver;

  /// Mientras se envía, los dos botones se deshabilitan y la acción muestra
  /// un indicador con [etiquetaEnviando] para el lector de pantalla.
  final bool enviando;
  final String? etiquetaEnviando;
  final Key? claveConfirmar;
  final Key? claveVolver;

  @override
  Widget build(BuildContext context) {
    final rojo = context.estados.peligro;
    return AlertDialog(
      title: Text(titulo),
      content: SingleChildScrollView(child: contenido),
      actions: [
        TextButton(
          key: claveVolver,
          onPressed: enviando
              ? null
              : alVolver ?? () => Navigator.of(context).pop(),
          child: Text(volver),
        ),
        FilledButton(
          key: claveConfirmar,
          style: peligro
              ? FilledButton.styleFrom(
                  backgroundColor: rojo,
                  foregroundColor: Theme.of(context).colorScheme.surface,
                )
              : null,
          onPressed: enviando ? null : alConfirmar,
          child: enviando
              ? Semantics(
                  label: etiquetaEnviando ?? accion,
                  child: const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Text(accion),
        ),
      ],
    );
  }
}

/// Pregunta de sí o no con [DialogoConfirmacion]. Devuelve `true` solo si se
/// confirma; volver, tocar fuera o el botón atrás devuelven `false`.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String accion,
  bool peligro = false,
  String volver = 'Volver',
  Key? clave,
  Key? claveVolver,
  Key? claveDialogo,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (contexto) => DialogoConfirmacion(
        key: claveDialogo,
        titulo: titulo,
        contenido: Text(mensaje),
        accion: accion,
        peligro: peligro,
        volver: volver,
        claveConfirmar: clave,
        claveVolver: claveVolver,
        alVolver: () => Navigator.of(contexto).pop(false),
        alConfirmar: () => Navigator.of(contexto).pop(true),
      ),
    ) ==
    true;
