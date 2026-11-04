import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../../../core/realtime/canal_tiempo_real.dart';
import '../../../../core/realtime/mensaje_tiempo_real.dart';

/// Para el técnico, en cualquier pestaña: con el aviso `offer.created`
/// (`realtime.v1.yaml`, solo al técnico de la oferta) muestra «Tienes una
/// oferta nueva» con «Ver», que lleva a la pestaña Servicios donde está la
/// oferta (SCRUM-80). Si ya está en Servicios no avisa: la oferta aparece ahí.
class EscuchaOfertas extends ConsumerStatefulWidget {
  const EscuchaOfertas({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<EscuchaOfertas> createState() => _EscuchaOfertasState();
}

class _EscuchaOfertasState extends ConsumerState<EscuchaOfertas> {
  CanalTiempoReal? _canal;
  StreamSubscription<MensajeTiempoReal>? _avisos;

  /// Se suscribe al canal actual; cambia si la sesión crea uno nuevo.
  void _escuchar(CanalTiempoReal canal) {
    if (identical(canal, _canal)) return;
    unawaited(_avisos?.cancel());
    _canal = canal;
    _avisos = canal.avisos
        .where((m) => m.tipo == MensajeTiempoReal.ofertaCreada)
        .listen((_) => _avisar());
  }

  void _avisar() {
    if (!mounted) return;
    final ubicacion = GoRouter.of(context)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;
    if (ubicacion == Rutas.actividad) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('aviso-oferta'),
          content: const Text('Tienes una oferta nueva.'),
          // La oferta vence a los 3 minutos (RN-M8).
          duration: const Duration(seconds: 30),
          showCloseIcon: true,
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () => context.go(Rutas.actividad),
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
