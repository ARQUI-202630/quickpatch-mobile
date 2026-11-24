import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Técnico del equipo del proveedor, solo con lo que necesitan otras features.
class MiembroEquipo {
  const MiembroEquipo({required this.userId, required this.nombre});

  final String userId;
  final String nombre;
}

/// Todo el equipo del proveedor. Lo usan los pagos recibidos (SCRUM-502) para
/// nombrar al técnico de cada pago y filtrar por técnico. Lo implementa la
/// feature `equipo` y lo conecta `app/composicion.dart`, así `pagos` no importa
/// a `equipo` (features/README.md, SCRUM-714).
final miembrosEquipoProvider = FutureProvider.autoDispose<List<MiembroEquipo>>(
  (ref) => throw UnimplementedError(
    'miembrosEquipoProvider se conecta en app/composicion.dart.',
  ),
);
