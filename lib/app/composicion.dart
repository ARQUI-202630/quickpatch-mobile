import 'package:flutter_riverpod/misc.dart';

import '../core/equipo/miembros_equipo.dart';
import '../features/equipo/data/repositorio_equipo.dart';

/// Conecta los puertos de `core/` con las features que los implementan
/// (SCRUM-714): así una feature usa datos de otra sin importarla. Se pasa como
/// `overrides` del `ProviderScope` de la app (main.dart) y de las pruebas que
/// arman la app completa.
final List<Override> composicionDeFeatures = [
  miembrosEquipoProvider.overrideWith(
    (ref) async => [
      for (final t in await ref.watch(equipoCompletoProvider.future))
        MiembroEquipo(userId: t.userId, nombre: t.nombre),
    ],
  ),
];
