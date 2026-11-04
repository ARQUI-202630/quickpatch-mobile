import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notificaciones/contador_notificaciones.dart';
import '../../core/realtime/canal_tiempo_real.dart';
import '../../core/realtime/mensaje_tiempo_real.dart';

/// Mantiene al día el contador del buzón (SCRUM-459): lo vuelve a consultar
/// con cada aviso del canal en tiempo real y, si el canal no está
/// conectado, cada 30 s (ADR-023).
class EscuchaNotificaciones extends ConsumerStatefulWidget {
  const EscuchaNotificaciones({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<EscuchaNotificaciones> createState() =>
      _EscuchaNotificacionesState();
}

class _EscuchaNotificacionesState extends ConsumerState<EscuchaNotificaciones> {
  CanalTiempoReal? _canal;
  StreamSubscription<MensajeTiempoReal>? _avisos;
  Timer? _respaldo;

  @override
  void initState() {
    super.initState();
    _respaldo = Timer.periodic(MensajeTiempoReal.intervaloRespaldo, (_) {
      if (_canal?.estado.value != EstadoCanal.conectado) _actualizar();
    });
  }

  void _actualizar() {
    if (mounted) ref.invalidate(contadorNotificacionesProvider);
  }

  /// Se suscribe al canal actual; cambia si la sesión crea uno nuevo.
  void _escuchar(CanalTiempoReal canal) {
    if (identical(canal, _canal)) return;
    unawaited(_avisos?.cancel());
    _canal = canal;
    _avisos = canal.avisos.listen((_) => _actualizar());
  }

  @override
  void dispose() {
    _respaldo?.cancel();
    unawaited(_avisos?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _escuchar(ref.watch(canalTiempoRealProvider));
    return widget.child;
  }
}
