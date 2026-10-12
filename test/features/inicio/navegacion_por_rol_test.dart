import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/router/rutas.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';
import 'package:quickpatch_mobile/features/inicio/domain/navegacion_por_rol.dart';
import 'package:quickpatch_mobile/features/inicio/presentation/paginas/cuenta_page.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/icono_categoria.dart';

void main() {
  group('destinosPara', () {
    List<String> etiquetas(RolUsuario rol) =>
        destinosPara(rol).map((d) => d.etiqueta).toList();

    test('cada rol de la app tiene Inicio, su trabajo y Cuenta', () {
      expect(etiquetas(RolUsuario.cliente), [
        'Inicio',
        'Solicitudes',
        'Cuenta',
      ]);
      expect(etiquetas(RolUsuario.empresaContacto), [
        'Inicio',
        'Solicitudes',
        'Cuenta',
      ]);
      expect(etiquetas(RolUsuario.tecnico), ['Inicio', 'Ofertas', 'Cuenta']);
      expect(etiquetas(RolUsuario.proveedor), ['Inicio', 'Equipo', 'Cuenta']);
    });

    test('la administración no tiene pestañas (usa el panel web)', () {
      expect(destinosPara(RolUsuario.adminTenant), isEmpty);
      expect(destinosPara(RolUsuario.adminPlataforma), isEmpty);
    });

    test('las rutas son las de las pestañas', () {
      for (final rol in RolUsuario.values.where((r) => r.usaAppMovil)) {
        expect(destinosPara(rol).map((d) => d.ruta), [
          Rutas.inicio,
          Rutas.actividad,
          Rutas.cuenta,
        ]);
      }
    });
  });

  test('indiceDestino ubica la pestaña activa', () {
    final destinos = destinosPara(RolUsuario.cliente);
    expect(indiceDestino(destinos, Rutas.inicio), 0);
    expect(indiceDestino(destinos, Rutas.cuenta), 2);
    expect(indiceDestino(destinos, Rutas.nuevaSolicitud), isNull);
  });

  test('nuevaSolicitudEn codifica la categoría', () {
    expect(Rutas.nuevaSolicitudEn('c-1'), '/solicitudes/nueva?categoria=c-1');
    expect(Rutas.nuevaSolicitudEn('a b'), '/solicitudes/nueva?categoria=a+b');
  });

  group('iconoCategoria', () {
    test('reconoce el nombre sin importar tildes ni mayúsculas', () {
      expect(iconoCategoria('Plomería'), Icons.plumbing_outlined);
      expect(iconoCategoria('ELÉCTRICO'), Icons.electrical_services_outlined);
      expect(iconoCategoria('Cerrajería'), Icons.key_outlined);
      expect(iconoCategoria('Aire acondicionado'), Icons.ac_unit_outlined);
    });

    test('electrodomésticos no se confunde con eléctrico', () {
      expect(iconoCategoria('Electrodomésticos'), Icons.kitchen_outlined);
    });

    test('un nombre desconocido usa la herramienta genérica', () {
      expect(iconoCategoria('Otra cosa'), Icons.handyman_outlined);
    });
  });

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
