import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/core/session/controlador_sesion.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';

import '../../helpers/fakes.dart';

/// Estado de la sesión (core/session). El login y el registro están en
/// test/features/autenticacion/acciones_sesion_test.dart.
void main() {
  late AlmacenSeguroEnMemoria memoria;

  ProviderContainer crear() {
    final c = ProviderContainer(
      overrides: [almacenSeguroProvider.overrideWithValue(memoria)],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() => memoria = AlmacenSeguroEnMemoria());

  test('sin sesión guardada empieza en null', () async {
    expect(await crear().read(controladorSesionProvider.future), isNull);
  });

  test('restaura una sesión vigente y descarta una vencida', () async {
    await AlmacenSesion(memoria).guardar(sesionDePrueba());
    expect(await crear().read(controladorSesionProvider.future), isNotNull);

    await AlmacenSesion(memoria)
        .guardar(sesionDePrueba(expiraEn: DateTime.utc(2020)));
    expect(await crear().read(controladorSesionProvider.future), isNull);
    expect(memoria.datos, isEmpty);
  });

  test('inicia y cierra sesión', () async {
    final c = crear();
    await c.read(controladorSesionProvider.future);
    await c
        .read(controladorSesionProvider.notifier)
        .iniciar(sesionDePrueba(rol: RolUsuario.tecnico));
    expect(
      c.read(controladorSesionProvider).value?.usuario.rol,
      RolUsuario.tecnico,
    );
    expect(memoria.datos, isNotEmpty);

    await c.read(controladorSesionProvider.notifier).cerrarSesion();
    expect(c.read(controladorSesionProvider).value, isNull);
    expect(memoria.datos, isEmpty);
  });
}
