import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/core/errors/app_exception.dart';
import 'package:quickpatch_mobile/core/errors/codigo_error.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';
import 'package:quickpatch_mobile/core/session/sesion.dart';
import 'package:quickpatch_mobile/features/autenticacion/data/repositorio_autenticacion_impl.dart';
import 'package:quickpatch_mobile/features/autenticacion/domain/datos_registro.dart';
import 'package:quickpatch_mobile/features/autenticacion/domain/repositorio_autenticacion.dart';
import 'package:quickpatch_mobile/features/autenticacion/presentation/controlador_sesion.dart';

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
        .iniciarSesion(email: 'a@b.co', password: 'x');
    expect(
      c.read(controladorSesionProvider).value?.usuario.rol,
      RolUsuario.tecnico,
    );
    expect(memoria.datos, isNotEmpty);

    await c.read(controladorSesionProvider.notifier).cerrarSesion();
    expect(c.read(controladorSesionProvider).value, isNull);
    expect(memoria.datos, isEmpty);
  });

  test('un error de login no cambia el estado', () async {
    repositorio.error = const AppException(CodigoError.accountLocked);
    final c = crear();
    await c.read(controladorSesionProvider.future);
    await expectLater(
      c
          .read(controladorSesionProvider.notifier)
          .iniciarSesion(email: 'a@b.co', password: 'x'),
      throwsA(isA<AppException>()),
    );
    expect(c.read(controladorSesionProvider).value, isNull);
  });

  test('registrar crea la cuenta y deja la sesión iniciada', () async {
    final c = crear();
    await c.read(controladorSesionProvider.future);
    await c
        .read(controladorSesionProvider.notifier)
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
}
