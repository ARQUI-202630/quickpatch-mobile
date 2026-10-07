import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';
import 'package:quickpatch_mobile/features/inicio/domain/opciones_por_rol.dart';

void main() {
  test('cada rol móvil tiene opciones y la administración ninguna', () {
    for (final rol in RolUsuario.values) {
      expect(opcionesPara(rol).isNotEmpty, rol.usaAppMovil, reason: rol.name);
    }
    expect(opcionesPara(RolUsuario.proveedor).single.requisito, 'RF-16');
  });
}
