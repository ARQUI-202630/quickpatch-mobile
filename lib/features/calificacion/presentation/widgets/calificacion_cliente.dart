import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/codigo_error.dart';
import '../../../../shared/widgets/boton_principal.dart';
import '../../../../shared/widgets/mensaje_error.dart';
import '../../../solicitudes/domain/modelos.dart';
import '../../../solicitudes/presentation/widgets/cotizacion_tecnico.dart'
    show SeccionCotizacion;
import '../../data/repositorio_calificacion.dart';
import '../../domain/calificacion.dart';

const _estrellas = 5;
const _comentarioMaximo = 500;

/// Calificación del servicio en el detalle del cliente (RF-12, SCRUM-86;
/// service-request 1.10.0): puntaje de 1 a 5 y comentario opcional, solo en
/// `pagado` y una sola vez (RN-R1 a RN-R3).
///
/// Desde service-request 1.12.0 el detalle trae la calificación (`rating`):
/// al volver a abrir una solicitud ya calificada se ven sus estrellas y su
/// comentario, no el formulario. Con un detalle anterior (`rating` ausente),
/// `409 ya-calificada` confirma que ya existe, sin sus estrellas.
class CalificacionCliente extends ConsumerStatefulWidget {
  const CalificacionCliente({
    required this.solicitud,
    required this.alCambiar,
    super.key,
  });

  final Solicitud solicitud;

  /// Vuelve a pedir la solicitud.
  final VoidCallback alCambiar;

  static bool aplica(EstadoSolicitud estado) =>
      estado == EstadoSolicitud.pagado;

  @override
  ConsumerState<CalificacionCliente> createState() =>
      _CalificacionClienteState();
}

class _CalificacionClienteState extends ConsumerState<CalificacionCliente> {
  final _comentario = TextEditingController();
  int? _puntaje;
  bool _enviando = false;
  AppException? _error;
  Calificacion? _registrada;
  bool _yaCalificada = false;

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final puntaje = _puntaje;
    if (puntaje == null) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final registrada = await ref
          .read(repositorioCalificacionProvider)
          .calificar(
            widget.solicitud.id,
            puntaje: puntaje,
            comentario: _comentario.text.trim(),
          );
      if (mounted) setState(() => _registrada = registrada);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.codigo == CodigoError.alreadyRated) {
          _yaCalificada = true;
        } else {
          _error = e;
        }
      });
      if (e.codigo == CodigoError.invalidStateTransition) widget.alCambiar();
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_registrada case final registrada?) {
      return SeccionCotizacion(
        key: const Key('calificacion-registrada'),
        titulo: 'Tu calificación',
        child: _Registrada(registrada.puntaje, registrada.comentario),
      );
    }
    if (widget.solicitud.calificacion case final delDetalle?) {
      return SeccionCotizacion(
        key: const Key('calificacion-del-detalle'),
        titulo: 'Tu calificación',
        child: _Registrada(delDetalle.puntaje, delDetalle.comentario),
      );
    }
    if (_yaCalificada) {
      return SeccionCotizacion(
        key: const Key('calificacion-existente'),
        titulo: 'Tu calificación',
        child: Text(CodigoError.alreadyRated.mensaje),
      );
    }
    final errorComentario = _error?.errorDe('comment');
    return SeccionCotizacion(
      key: const Key('calificacion-cliente'),
      titulo: 'Califica el servicio',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (var n = 1; n <= _estrellas; n++)
                IconButton(
                  key: Key('estrella-$n'),
                  tooltip: '$n de $_estrellas estrellas',
                  isSelected: n == _puntaje,
                  onPressed: _enviando
                      ? null
                      : () => setState(() => _puntaje = n),
                  icon: _Estrella(llena: n <= (_puntaje ?? 0), tamano: 32),
                ),
            ],
          ),
          const SizedBox(height: QpEspacio.e3),
          TextField(
            key: const Key('campo-comentario'),
            controller: _comentario,
            enabled: !_enviando,
            maxLength: _comentarioMaximo,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Comentario (opcional)',
              errorText: errorComentario,
            ),
          ),
          if (_error case final error? when errorComentario == null) ...[
            const SizedBox(height: QpEspacio.e3),
            MensajeError(error.mensaje, key: const Key('mensaje-error')),
          ],
          const SizedBox(height: QpEspacio.e3),
          BotonPrincipal(
            key: const Key('boton-calificar'),
            texto: 'Enviar calificación',
            cargando: _enviando,
            alPresionar: _puntaje == null ? null : _enviar,
          ),
        ],
      ),
    );
  }
}

class _Registrada extends StatelessWidget {
  const _Registrada(this.puntaje, this.comentario);

  final int puntaje;
  final String? comentario;

  @override
  Widget build(BuildContext context) {
    final comentario = this.comentario;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Calificación: $puntaje de $_estrellas',
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var n = 1; n <= _estrellas; n++)
                _Estrella(llena: n <= puntaje, tamano: 24),
            ],
          ),
        ),
        if (comentario != null && comentario.isNotEmpty) ...[
          const SizedBox(height: QpEspacio.e2),
          Text(comentario, key: const Key('comentario-registrado')),
        ],
      ],
    );
  }
}

class _Estrella extends StatelessWidget {
  const _Estrella({required this.llena, required this.tamano});

  final bool llena;
  final double tamano;

  @override
  Widget build(BuildContext context) => Icon(
    llena ? Icons.star_rounded : Icons.star_outline_rounded,
    size: tamano,
    color: Theme.of(context).colorScheme.primary,
  );
}
