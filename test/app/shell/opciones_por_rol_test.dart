import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/shell/opciones_por_rol.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';

void main() {
  test('cada rol móvil tiene opciones y la administración ninguna', () {
    for (final rol in RolUsuario.values) {
      expect(opcionesPara(rol).isNotEmpty, rol.usaAppMovil, reason: rol.name);
    }
    expect(opcionesPara(RolUsuario.proveedor).single.requisito, 'RF-16');
  });
}
