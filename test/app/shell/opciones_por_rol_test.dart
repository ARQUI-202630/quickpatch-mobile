import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/router/rutas.dart';
import 'package:quickpatch_mobile/app/shell/opciones_por_rol.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';

void main() {
  test('cada rol móvil tiene opciones y la administración ninguna', () {
    for (final rol in RolUsuario.values) {
      expect(opcionesPara(rol).isNotEmpty, rol.usaAppMovil, reason: rol.name);
    }
    expect(opcionesPara(RolUsuario.proveedor).single.requisito, 'RF-16');
  });

  test('ninguna opción de inicio queda como «Próximamente»', () {
    for (final rol in RolUsuario.values) {
      for (final opcion in opcionesPara(rol)) {
        expect(
          opcion.disponible,
          isTrue,
          reason: '${rol.name}: ${opcion.titulo} (${opcion.requisito})',
        );
      }
    }
  });

  test('el pago no es una opción de inicio: se hace en el detalle (RF-22)', () {
    for (final rol in [RolUsuario.cliente, RolUsuario.empresaContacto]) {
      expect(
        opcionesPara(rol).where((o) => o.requisito == 'RF-22'),
        isEmpty,
        reason: rol.name,
      );
    }
  });

  test('el proveedor llega a su equipo por la pestaña de actividad', () {
    final opcion = opcionesPara(RolUsuario.proveedor).single;
    expect(opcion.ruta, Rutas.actividad);
    expect(opcion.esPestana, isTrue);
  });
}
