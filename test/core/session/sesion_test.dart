import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';
import 'package:quickpatch_mobile/core/session/sesion.dart';

import '../../helpers/fakes.dart';

void main() {
  group('RolUsuario', () {
    test('reconoce los valores del contrato', () {
      expect(
        RolUsuario.desdeValor('empresa_contacto'),
        RolUsuario.empresaContacto,
      );
      expect(RolUsuario.desdeValor('otro'), isNull);
      expect(RolUsuario.desdeValor(null), isNull);
    });

    test('solo la administración queda fuera de la app móvil', () {
      expect(RolUsuario.values.where((r) => !r.usaAppMovil), [
        RolUsuario.adminTenant,
        RolUsuario.adminPlataforma,
      ]);
    });
  });

  group('Sesion', () {
    final ahora = DateTime.utc(2026, 10, 5, 12);

    test('se construye desde el login y calcula el vencimiento', () {
      final s = Sesion.desdeLogin(loginJson(), ahora);
      expect(s.accessToken, 'token-acceso');
      expect(s.usuario.rol, RolUsuario.cliente);
      expect(s.expiraEn, ahora.add(const Duration(minutes: 15)));
      expect(s.estaVencida(ahora), isFalse);
      expect(s.estaVencida(ahora.add(const Duration(minutes: 15))), isTrue);
    });

    test('ida y vuelta por JSON', () {
      final s = Sesion.desdeLogin(loginJson(rol: 'tecnico'), ahora);
      final copia = Sesion.fromJson(s.toJson());
      expect(copia.usuario.rol, RolUsuario.tecnico);
      expect(copia.expiraEn, s.expiraEn);
      expect(copia.refreshToken, s.refreshToken);
    });

    test('un rol desconocido es un error de formato', () {
      expect(
        () => Sesion.desdeLogin(loginJson(rol: 'hacker'), ahora),
        throwsFormatException,
      );
    });
  });

  group('AlmacenSesion', () {
    test('guarda, carga y borra', () async {
      final memoria = AlmacenSeguroEnMemoria();
      final almacen = AlmacenSesion(memoria);
      expect(await almacen.cargar(), isNull);

      await almacen.guardar(sesionDePrueba());
      expect(almacen.actual?.accessToken, 'token-acceso');
      expect(
        (await AlmacenSesion(memoria).cargar())?.usuario.fullName,
        'Ana Gómez',
      );

      await almacen.borrar();
      expect(almacen.actual, isNull);
      expect(memoria.datos, isEmpty);
    });

    test('descarta una sesión dañada', () async {
      final memoria = AlmacenSeguroEnMemoria()
        ..datos['quickpatch.sesion'] = '{';
      expect(await AlmacenSesion(memoria).cargar(), isNull);
      expect(memoria.datos, isEmpty);
    });
  });
}
