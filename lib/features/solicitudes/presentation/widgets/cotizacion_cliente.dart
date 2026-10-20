import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/reloj.dart';
import '../../data/repositorio_solicitudes.dart';
import '../../domain/modelos.dart';
import 'cotizacion_tecnico.dart' show SeccionCotizacion;
import 'desglose_cotizacion.dart';

/// Cotización que recibe el cliente (RF-35, SCRUM-489; service-request
/// 1.6.0): en `cotizado`, el desglose con aceptar y rechazar; en
/// `cotizacion_aceptada`, la aceptada. Si la cotización venció o ya se
/// respondió, el backend responde `409 transicion-invalida` y la pantalla
/// recarga el estado.
class CotizacionCliente extends ConsumerWidget {
  const CotizacionCliente({
    required this.solicitud,
    required this.alCambiar,
    super.key,
  });

  final Solicitud solicitud;

  /// Vuelve a pedir la solicitud y sus cotizaciones.
  final VoidCallback alCambiar;

  static bool aplica(EstadoSolicitud estado) =>
      estado == EstadoSolicitud.cotizado ||
      estado == EstadoSolicitud.cotizacionAceptada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!aplica(solicitud.estado)) return const SizedBox.shrink();
    final buscada = solicitud.estado == EstadoSolicitud.cotizado
        ? EstadoCotizacion.pendiente
        : EstadoCotizacion.aceptada;
    return ref
        .watch(cotizacionesProvider(solicitud.id))
        .when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          loading: () => const SeccionCotizacion(
            titulo: 'Cotización',
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SeccionCotizacion(
            key: const Key('error-cotizaciones'),
            titulo: 'Cotización',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('No pudimos cargar la cotización.'),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: alCambiar,
                    child: const Text('Reintentar'),
                  ),
                ),
              ],
            ),
          ),
          data: (lista) {
            final cotizacion = lista
                .where((c) => c.estado == buscada)
                .lastOrNull;
            // El estado de la solicitud llegó antes que la cotización: el
            // siguiente aviso o la consulta de respaldo lo ponen al día.
            if (cotizacion == null) return const SizedBox.shrink();
            return buscada == EstadoCotizacion.aceptada
                ? SeccionCotizacion(
                    key: const Key('cotizacion-aceptada'),
                    titulo: 'Cotización aceptada',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DesgloseCotizacion(cotizacion),
                        const SizedBox(height: QpEspacio.e2),
                        const Text(
                          'Este total es lo que pagarás cuando el técnico '
                          'termine el servicio.',
                        ),
                      ],
                    ),
                  )
                : _CotizacionPendiente(
                    solicitudId: solicitud.id,
                    cotizacion: cotizacion,
                    alCambiar: alCambiar,
                  );
          },
        );
  }
}

class _CotizacionPendiente extends ConsumerStatefulWidget {
  const _CotizacionPendiente({
    required this.solicitudId,
    required this.cotizacion,
    required this.alCambiar,
  });

  final String solicitudId;
  final Cotizacion cotizacion;
  final VoidCallback alCambiar;

  @override
  ConsumerState<_CotizacionPendiente> createState() =>
      _CotizacionPendienteState();
}

class _CotizacionPendienteState extends ConsumerState<_CotizacionPendiente> {
  var _aceptando = false;

  Future<void> _aceptar() async {
    final c = widget.cotizacion;
    final mensajero = ScaffoldMessenger.of(context);
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Aceptar la cotización?'),
        content: Text(
          'Pagarás ${c.total.formatear()} cuando el técnico termine el '
          'servicio. Después de aceptarla no se puede cambiar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            key: const Key('confirmar-aceptar-cotizacion'),
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() => _aceptando = true);
    String aviso;
    try {
      await ref
          .read(repositorioSolicitudesProvider)
          .aceptarCotizacion(widget.solicitudId, c.id);
      aviso =
          'Aceptaste la cotización. El técnico ya puede iniciar el '
          'servicio.';
    } on AppException catch (e) {
      aviso = e.status == 409 ? avisoConflicto : e.mensaje;
    }
    if (mounted) setState(() => _aceptando = false);
    mensajero.showSnackBar(SnackBar(content: Text(aviso)));
    widget.alCambiar();
  }

  Future<void> _rechazar() async {
    final mensajero = ScaffoldMessenger.of(context);
    final aviso = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoRechazar(
        solicitudId: widget.solicitudId,
        cotizacion: widget.cotizacion,
      ),
    );
    if (aviso == null) return;
    mensajero.showSnackBar(SnackBar(content: Text(aviso)));
    widget.alCambiar();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cotizacion;
    final vigente = c.respondibleEn(ref.watch(relojProvider)());
    final peligro = context.estados.peligro;
    final texto = Theme.of(context).textTheme;
    return SeccionCotizacion(
      key: const Key('cotizacion-pendiente'),
      titulo: 'Tienes una cotización',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesgloseCotizacion(c),
          const SizedBox(height: QpEspacio.e4),
          if (!vigente)
            Text(
              'La cotización venció sin respuesta; la solicitud se cancelará.',
              key: const Key('cotizacion-vencida'),
              style: texto.bodyMedium?.copyWith(color: peligro),
            )
          else ...[
            FilledButton.icon(
              key: const Key('boton-aceptar-cotizacion'),
              onPressed: _aceptando ? null : _aceptar,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Aceptar cotización'),
            ),
            const SizedBox(height: QpEspacio.e2),
            OutlinedButton.icon(
              key: const Key('boton-rechazar-cotizacion'),
              style: OutlinedButton.styleFrom(
                foregroundColor: peligro,
                side: BorderSide(color: peligro),
              ),
              onPressed: _aceptando ? null : _rechazar,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Rechazar'),
            ),
            if (c.esLaUltima) ...[
              const SizedBox(height: QpEspacio.e2),
              Text(
                'Es la tercera cotización: si la rechazas, la solicitud se '
                'cancela.',
                key: const Key('aviso-ultima-cotizacion'),
                textAlign: TextAlign.center,
                style: texto.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Aviso de un `409`: la cotización venció o alguien ya la respondió.
const avisoConflicto =
    'La cotización ya no se puede responder: venció o ya cambió. '
    'Actualizamos la solicitud.';

/// Pide un motivo opcional y rechaza. Se cierra con el aviso para el cliente,
/// o con `null` si vuelve sin rechazar.
class _DialogoRechazar extends ConsumerStatefulWidget {
  const _DialogoRechazar({required this.solicitudId, required this.cotizacion});

  final String solicitudId;
  final Cotizacion cotizacion;

  @override
  ConsumerState<_DialogoRechazar> createState() => _DialogoRechazarState();
}

class _DialogoRechazarState extends ConsumerState<_DialogoRechazar> {
  final _motivo = TextEditingController();
  String? _error;
  var _enviando = false;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final motivo = _motivo.text.trim();
    if (motivo.isNotEmpty && motivo.length < LimitesCotizacion.motivoMinimo) {
      setState(
        () => _error =
            'El motivo debe tener al menos ${LimitesCotizacion.motivoMinimo} '
            'caracteres, o déjalo vacío.',
      );
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final decision = await ref
          .read(repositorioSolicitudesProvider)
          .rechazarCotizacion(
            widget.solicitudId,
            widget.cotizacion.id,
            motivo: motivo,
          );
      if (!mounted) return;
      Navigator.of(context).pop(
        decision.estadoSolicitud == EstadoSolicitud.cancelado
            ? 'Rechazaste la tercera cotización y la solicitud se canceló.'
            : 'Rechazaste la cotización. El técnico puede enviarte otra.',
      );
    } on AppException catch (e) {
      if (!mounted) return;
      if (e.status == 409) {
        Navigator.of(context).pop(avisoConflicto);
        return;
      }
      setState(() {
        _enviando = false;
        _error = e.errorDe('reason') ?? e.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final peligro = context.estados.peligro;
    return AlertDialog(
      title: const Text('¿Rechazar la cotización?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.cotizacion.esLaUltima
                  ? 'Es la tercera cotización: si la rechazas, la solicitud '
                        'se cancela y no podrás reactivarla.'
                  : 'El técnico podrá enviarte otra cotización.',
              key: const Key('explicacion-rechazo'),
            ),
            const SizedBox(height: QpEspacio.e4),
            TextField(
              key: const Key('campo-motivo-rechazo'),
              controller: _motivo,
              enabled: !_enviando,
              minLines: 2,
              maxLines: 4,
              maxLength: LimitesCotizacion.motivoMaximo,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Por ejemplo: el valor es muy alto',
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.of(context).pop(),
          child: const Text('Volver'),
        ),
        FilledButton(
          key: const Key('confirmar-rechazo'),
          style: FilledButton.styleFrom(
            backgroundColor: peligro,
            foregroundColor: esquema.surface,
          ),
          onPressed: _enviando ? null : _confirmar,
          child: _enviando
              ? Semantics(
                  label: 'Rechazando',
                  child: const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Text('Rechazar'),
        ),
      ],
    );
  }
}
