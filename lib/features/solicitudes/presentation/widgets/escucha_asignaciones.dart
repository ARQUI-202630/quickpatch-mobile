import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../../../core/realtime/canal_tiempo_real.dart';
import '../../../../core/realtime/mensaje_tiempo_real.dart';
import '../../data/repositorio_solicitudes.dart';

/// Para el técnico: cuando el canal en tiempo real avisa que le asignaron una
/// solicitud (`service-request.status-changed` con `asignado`, que también le
/// llega al técnico asignado según `realtime.v1.yaml`), muestra un aviso con
/// «Ver» que abre su detalle (SCRUM-92). Mientras no exista el historial del
/// técnico (RF-17) es la forma de llegar al servicio; con la SCRUM-80 se
/// agrega la navegación al aceptar la oferta.
///
/// Si el cliente o el administrador cancelan un servicio que tenía asignado
/// (`cancelado`, RF-36), avisa que se canceló y recarga su detalle (SCRUM-477).
/// No ofrece «Ver»: fuera de `asignado`–`completado` el técnico ya no ve los
/// datos del cliente (RN-SR13).
class EscuchaAsignaciones extends ConsumerStatefulWidget {
  const EscuchaAsignaciones({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<EscuchaAsignaciones> createState() =>
      _EscuchaAsignacionesState();
}

class _EscuchaAsignacionesState extends ConsumerState<EscuchaAsignaciones> {
  CanalTiempoReal? _canal;
  StreamSubscription<MensajeTiempoReal>? _avisos;

  /// Se suscribe al canal actual; cambia si la sesión crea uno nuevo.
  void _escuchar(CanalTiempoReal canal) {
    if (identical(canal, _canal)) return;
    unawaited(_avisos?.cancel());
    _canal = canal;
    _avisos = canal.avisos
        .where(
          (m) =>
              m.tipo == MensajeTiempoReal.cambioDeEstado &&
              m.serviceRequestId != null,
        )
        .listen((m) {
          switch (m.status) {
            case 'asignado':
              _avisar(m.serviceRequestId!);
            case 'cancelado':
              _avisarCancelacion(m.serviceRequestId!);
          }
        });
  }

  void _avisarCancelacion(String id) {
    if (!mounted) return;
    ref.invalidate(solicitudProvider(id));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          key: Key('aviso-cancelacion'),
          content: Text(
            'Se canceló un servicio que tenías asignado. Volverás a '
            'recibir ofertas.',
          ),
          duration: Duration(seconds: 30),
          showCloseIcon: true,
        ),
      );
  }

  void _avisar(String id) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('aviso-asignacion'),
          content: const Text('Te asignaron un servicio.'),
          duration: const Duration(seconds: 30),
          showCloseIcon: true,
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () => context.push(Rutas.solicitudAsignada(id)),
          ),
        ),
      );
  }

  @override
  void dispose() {
    unawaited(_avisos?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _escuchar(ref.watch(canalTiempoRealProvider));
    return widget.child;
  }
}
