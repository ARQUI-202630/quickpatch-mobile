import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/core/errors/app_exception.dart';
import 'package:quickpatch_mobile/core/errors/codigo_error.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/core/session/controlador_sesion.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';
import 'package:quickpatch_mobile/core/session/sesion.dart';
import 'package:quickpatch_mobile/features/autenticacion/data/repositorio_autenticacion_impl.dart';
import 'package:quickpatch_mobile/features/autenticacion/domain/datos_registro.dart';
import 'package:quickpatch_mobile/features/autenticacion/domain/repositorio_autenticacion.dart';
import 'package:quickpatch_mobile/features/autenticacion/presentation/acciones_sesion.dart';

import '../../helpers/fakes.dart';

class RepositorioFalso implements RepositorioAutenticacion {
  AppException? error;

  @override
  Future<Sesion> iniciarSesion({
    required String email,
    required String password,
  }) async {
    if (error != null) throw error!;
    return sesionDePrueba(rol: RolUsuario.tecnico);
  }

  final registros = <DatosRegistro>[];

  @override
  Future<void> registrar(DatosRegistro datos) async => registros.add(datos);

  final registrosTecnico = <DatosRegistroTecnico>[];

  @override
  Future<void> registrarTecnico(DatosRegistroTecnico datos) async {
    if (error != null) throw error!;
    registrosTecnico.add(datos);
  }
}

void main() {
  late AlmacenSeguroEnMemoria memoria;
  late RepositorioFalso repositorio;

  ProviderContainer crear() {
    final c = ProviderContainer(
      overrides: [
        almacenSeguroProvider.overrideWithValue(memoria),
        repositorioAutenticacionProvider.overrideWithValue(repositorio),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    memoria = AlmacenSeguroEnMemoria();
    repositorio = RepositorioFalso();
  });

  test('inicia sesión y la entrega a core/session', () async {
    final c = crear();
    await c.read(controladorSesionProvider.future);
    await c
        .read(accionesSesionProvider)
        .iniciarSesion(email: 'a@b.co', password: 'x');
    expect(
      c.read(controladorSesionProvider).value?.usuario.rol,
      RolUsuario.tecnico,
    );
    expect(memoria.datos, isNotEmpty);
  });

  test('un error de login no cambia el estado', () async {
    repositorio.error = const AppException(CodigoError.accountLocked);
    final c = crear();
    await c.read(controladorSesionProvider.future);
    await expectLater(
      c
          .read(accionesSesionProvider)
          .iniciarSesion(email: 'a@b.co', password: 'x'),
      throwsA(isA<AppException>()),
    );
    expect(c.read(controladorSesionProvider).value, isNull);
  });

  test('registrar crea la cuenta y deja la sesión iniciada', () async {
    final c = crear();
    await c.read(controladorSesionProvider.future);
    await c
        .read(accionesSesionProvider)
        .registrarEIniciarSesion(
          const DatosRegistro(
            tipo: TipoCuenta.hogar,
            nombreCompleto: 'Ana',
            email: 'a@b.co',
            password: 'secreta123',
          ),
        );
    expect(repositorio.registros.single.email, 'a@b.co');
    expect(c.read(controladorSesionProvider).value, isNotNull);
  });

  group('registro de técnico (SCRUM-55)', () {
    const datos = DatosRegistroTecnico(
      rol: RolProfesional.proveedor,
      nombreCompleto: 'Luis Pérez',
      email: 'luis@correo.co',
      password: 'secreta123',
      telefono: '3001234567',
      documento: '1012345678',
      especialidadId: 'c-1',
    );

    test('registra y deja la sesión iniciada', () async {
      final c = crear();
      await c.read(controladorSesionProvider.future);
      await c
          .read(accionesSesionProvider)
          .registrarTecnicoEIniciarSesion(datos);
      expect(repositorio.registrosTecnico.single.rol, RolProfesional.proveedor);
      expect(c.read(controladorSesionProvider).value, isNotNull);
    });

    test('si el registro falla no inicia sesión', () async {
      repositorio.error = const AppException(CodigoError.duplicateResource);
      final c = crear();
      await c.read(controladorSesionProvider.future);
      await expectLater(
        c.read(accionesSesionProvider).registrarTecnicoEIniciarSesion(datos),
        throwsA(isA<AppException>()),
      );
      expect(c.read(controladorSesionProvider).value, isNull);
    });
  });
}
