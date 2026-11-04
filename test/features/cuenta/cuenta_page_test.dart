import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';
import 'package:quickpatch_mobile/features/cuenta/presentation/paginas/cuenta_page.dart';

void main() {
  test('iniciales toma hasta dos palabras', () {
    expect(iniciales('Ana Gómez'), 'AG');
    expect(iniciales('  ana   maría gómez '), 'AM');
    expect(iniciales('Ana'), 'A');
    expect(iniciales(''), '');
  });

  test('etiquetaRol nombra todos los roles', () {
    for (final rol in RolUsuario.values) {
      expect(etiquetaRol(rol), isNotEmpty);
    }
    expect(etiquetaRol(RolUsuario.tecnico), 'Técnico');
  });
}
