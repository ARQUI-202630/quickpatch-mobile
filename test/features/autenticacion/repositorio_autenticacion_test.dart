import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/core/errors/app_exception.dart';
import 'package:quickpatch_mobile/core/errors/codigo_error.dart';
import 'package:quickpatch_mobile/core/network/api_endpoints.dart';
import 'package:quickpatch_mobile/features/autenticacion/data/autenticacion_api.dart';
import 'package:quickpatch_mobile/features/autenticacion/data/repositorio_autenticacion_impl.dart';
import 'package:quickpatch_mobile/features/autenticacion/domain/datos_registro.dart';

import '../../helpers/fakes.dart';

void main() {
  late AdaptadorFalso adaptador;
  late RepositorioAutenticacionImpl repositorio;
  final ahora = DateTime.utc(2026, 10, 5, 12);

  setUp(() {
    adaptador = AdaptadorFalso((_) => respuestaJson(loginJson(), 200));
    final dio = Dio(BaseOptions(baseUrl: 'https://gw/api'))
      ..httpClientAdapter = adaptador;
    repositorio = RepositorioAutenticacionImpl(
      AutenticacionApi(dio),
      reloj: () => ahora,
    );
  });

  test('envía correo sin espacios y contraseña, y arma la sesión', () async {
    final sesion = await repositorio.iniciarSesion(
      email: '  ana.gomez@correo.com ',
      password: 'secreta',
    );
    expect(adaptador.ultima!.path, ApiEndpoints.login);
    expect(adaptador.ultima!.method, 'POST');
    expect(adaptador.ultima!.data, {
      'email': 'ana.gomez@correo.com',
      'password': 'secreta',
    });
    expect(sesion.usuario.fullName, 'Ana Gómez');
    expect(sesion.expiraEn, ahora.add(const Duration(seconds: 900)));
  });

  test('traduce INVALID_CREDENTIALS a AppException', () async {
    adaptador.responder = (_) =>
        respuestaJson({'status': 401, 'code': 'INVALID_CREDENTIALS'}, 401);
    await expectLater(
      repositorio.iniciarSesion(email: 'a@b.co', password: 'x'),
      throwsA(
        isA<AppException>().having(
          (e) => e.codigo,
          'codigo',
          CodigoError.invalidCredentials,
        ),
      ),
    );
  });

  test('registro de hogar envía solo los campos del contrato', () async {
    adaptador.responder = (_) =>
        respuestaJson({'userId': 'u', 'role': 'cliente'}, 201);
    await repositorio.registrar(
      const DatosRegistro(
        tipo: TipoCuenta.hogar,
        nombreCompleto: ' Ana ',
        email: ' ana@correo.com ',
        password: 'secreta123',
        telefono: '  ',
      ),
    );
    expect(adaptador.ultima!.path, ApiEndpoints.registroCliente);
    expect(adaptador.ultima!.headers['X-Channel-Id'], isNull);
    expect(adaptador.ultima!.extra['publico'], isTrue);
    expect(adaptador.ultima!.data, {
      'fullName': 'Ana',
      'email': 'ana@correo.com',
      'password': 'secreta123',
    });
  });

  test('registro de empresa agrega razón social y NIT', () async {
    adaptador.responder = (_) => respuestaJson({'userId': 'u'}, 201);
    await repositorio.registrar(
      const DatosRegistro(
        tipo: TipoCuenta.empresa,
        nombreCompleto: 'Laura',
        email: 'l@e.co',
        password: 'secreta123',
        telefono: '6011234567',
        razonSocial: ' Empresa SAS ',
        nit: '900',
      ),
    );
    expect(adaptador.ultima!.path, ApiEndpoints.registroEmpresa);
    expect(adaptador.ultima!.data, {
      'fullName': 'Laura',
      'email': 'l@e.co',
      'password': 'secreta123',
      'phone': '6011234567',
      'legalName': 'Empresa SAS',
      'nit': '900',
    });
  });

  group('registro de técnico (SCRUM-55)', () {
    const datos = DatosRegistroTecnico(
      rol: RolProfesional.tecnico,
      nombreCompleto: ' Luis Pérez ',
      email: ' luis@correo.co ',
      password: 'secreta123',
      telefono: ' 3001234567 ',
      documento: ' 1012345678 ',
      especialidadId: 'c-1',
    );

    test('es público y envía el cuerpo de RegisterTechnicianRequest', () async {
      adaptador.responder = (_) =>
          respuestaJson({'id': 'u', 'role': 'tecnico'}, 201);
      await repositorio.registrarTecnico(datos);
      expect(adaptador.ultima!.path, ApiEndpoints.registroTecnico);
      expect(adaptador.ultima!.method, 'POST');
      expect(adaptador.ultima!.extra['publico'], isTrue);
      expect(adaptador.ultima!.data, {
        'email': 'luis@correo.co',
        'password': 'secreta123',
        'fullName': 'Luis Pérez',
        'phone': '3001234567',
        'documentId': '1012345678',
        'specialtyId': 'c-1',
        'role': 'tecnico',
      });
      expect((adaptador.ultima!.data as Map).containsKey('tenantId'), isFalse);
    });

    test('el 409 de documento repetido conserva su tipo', () async {
      adaptador.responder = (_) => respuestaJson({
        'type': 'https://quickpatch.internal/problems/documento-registrado',
        'title': 'Documento registrado',
        'status': 409,
      }, 409);
      await expectLater(
        repositorio.registrarTecnico(datos),
        throwsA(
          isA<AppException>()
              .having((e) => e.codigo, 'codigo', CodigoError.duplicateResource)
              .having(
                (e) => e.esProblema('documento-registrado'),
                'documento',
                isTrue,
              )
              .having(
                (e) => e.esProblema('correo-registrado'),
                'correo',
                isFalse,
              ),
        ),
      );
    });
  });

  test('registro duplicado se traduce con el campo', () async {
    adaptador.responder = (_) => respuestaJson({
      'code': 'DUPLICATE_RESOURCE',
      'errors': [
        {'field': 'email', 'message': 'Ya está registrado.'},
      ],
    }, 409);
    await expectLater(
      repositorio.registrar(
        const DatosRegistro(
          tipo: TipoCuenta.hogar,
          nombreCompleto: 'A',
          email: 'a@b.co',
          password: 'secreta123',
        ),
      ),
      throwsA(
        isA<AppException>().having(
          (e) => e.errorDe('email'),
          'email',
          'Ya está registrado.',
        ),
      ),
    );
  });
}
