import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/app.dart';
import 'package:quickpatch_mobile/core/network/cliente_api.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';

import '../../helpers/fakes.dart';

/// SCRUM-55: registro de técnico o proveedor desde la app móvil.
void main() {
  late AdaptadorFalso adaptador;
  late List<RequestOptions> peticiones;
  late ResponseBody Function() respuestaCategorias;
  late ResponseBody Function() respuestaRegistro;

  ResponseBody categoriasOk() => respuestaJson([
    {'id': 'c-1', 'name': 'Plomería'},
    {'id': 'c-2', 'name': 'Electricidad'},
  ], 200);

  /// Respuesta de `POST /v1/auth/login` de un técnico recién registrado.
  Map<String, dynamic> loginTecnico() {
    final json = loginJson(rol: 'tecnico');
    (json['user'] as Map<String, dynamic>)
      ..['fullName'] = 'Luis Pérez'
      ..['verificationStatus'] = 'pendiente';
    return json;
  }

  setUp(() {
    peticiones = [];
    respuestaCategorias = categoriasOk;
    respuestaRegistro = () =>
        respuestaJson({'id': 'u-9', 'role': 'tecnico'}, 201);
    adaptador = AdaptadorFalso((opciones) {
      peticiones.add(opciones);
      final ruta = opciones.path;
      if (ruta.endsWith('/v1/service-requests/categories')) {
        return respuestaCategorias();
      }
      if (ruta.endsWith('/v1/auth/register/technician')) {
        return respuestaRegistro();
      }
      if (ruta.endsWith('/v1/auth/login')) {
        return respuestaJson(loginTecnico(), 200);
      }
      return respuestaJson(<String, dynamic>{}, 404);
    });
  });

  Future<void> abrirRegistro(
    WidgetTester tester, {
    double escalaTexto = 1,
    Brightness brillo = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = escalaTexto;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = brillo;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final container = ProviderContainer(
      overrides: [
        almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
      ],
    );
    addTearDown(container.dispose);
    container.read(clienteApiProvider).httpClientAdapter = adaptador;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QuickpatchApp(),
      ),
    );
    await tester.pumpAndSettle();
    final enlace = find.byKey(const Key('boton-ir-registro-tecnico'));
    await tester.ensureVisible(enlace);
    await tester.tap(enlace);
    await tester.pumpAndSettle();
  }

  Future<void> llenar(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('campo-nombre')), 'Luis Pérez');
    await tester.enterText(
      find.byKey(const Key('campo-email')),
      'luis@correo.co',
    );
    await tester.enterText(
      find.byKey(const Key('campo-telefono')),
      '3001234567',
    );
    await tester.enterText(
      find.byKey(const Key('campo-documento')),
      '1012345678',
    );
    await tester.tap(find.byKey(const Key('categoria-c-2')));
    await tester.enterText(
      find.byKey(const Key('campo-password')),
      'secreta123',
    );
    await tester.enterText(
      find.byKey(const Key('campo-confirmacion')),
      'secreta123',
    );
    await tester.pump();
  }

  Future<void> enviar(WidgetTester tester) async {
    final boton = find.byKey(const Key('boton-registrar-tecnico'));
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();
  }

  RequestOptions? registroEnviado() => peticiones
      .where((p) => p.path.endsWith('/v1/auth/register/technician'))
      .lastOrNull;

  testWidgets('carga las especialidades sin sesión, con el canal', (
    tester,
  ) async {
    await abrirRegistro(tester);

    expect(find.text('Registro de técnico o proveedor'), findsOneWidget);
    expect(find.text('Plomería'), findsOneWidget);
    expect(find.text('Electricidad'), findsOneWidget);
    final categorias = peticiones.firstWhere(
      (p) => p.path.endsWith('/v1/service-requests/categories'),
    );
    expect(categorias.headers['X-Channel-Id'], isNotNull);
    expect(categorias.headers['Authorization'], isNull);
  });

  testWidgets('valida los campos obligatorios y no envía nada', (tester) async {
    await abrirRegistro(tester);
    await enviar(tester);

    expect(find.text('Es obligatorio.'), findsWidgets);
    expect(find.text('Elige tu especialidad.'), findsOneWidget);
    expect(registroEnviado(), isNull);
  });

  testWidgets('aplica los límites del contrato y la confirmación', (
    tester,
  ) async {
    await abrirRegistro(tester);
    await llenar(tester);
    await tester.enterText(find.byKey(const Key('campo-telefono')), '123');
    await tester.enterText(find.byKey(const Key('campo-documento')), '12');
    await tester.enterText(
      find.byKey(const Key('campo-confirmacion')),
      'otra-clave',
    );
    await enviar(tester);

    expect(find.text('Usa al menos 7 caracteres.'), findsOneWidget);
    expect(find.text('Usa al menos 5 caracteres.'), findsOneWidget);
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(registroEnviado(), isNull);
  });

  testWidgets(
    'registra al proveedor, inicia sesión y muestra la verificación',
    (tester) async {
      await abrirRegistro(tester);
      await tester.tap(find.text('Proveedor'));
      await tester.pumpAndSettle();
      expect(find.text('Administras un equipo de técnicos.'), findsOneWidget);
      await llenar(tester);
      await enviar(tester);

      final registro = registroEnviado()!;
      expect(registro.method, 'POST');
      expect(registro.headers['X-Channel-Id'], isNotNull);
      expect(registro.data, {
        'email': 'luis@correo.co',
        'password': 'secreta123',
        'fullName': 'Luis Pérez',
        'phone': '3001234567',
        'documentId': '1012345678',
        'specialtyId': 'c-2',
        'role': 'proveedor',
      });
      expect(find.byKey(const Key('aviso-verificacion')), findsOneWidget);
    },
  );

  testWidgets('muestra el documento repetido (409) junto a su campo', (
    tester,
  ) async {
    respuestaRegistro = () => respuestaJson({
      'type': 'https://quickpatch.internal/problems/documento-registrado',
      'title': 'Documento registrado',
      'status': 409,
    }, 409);
    await abrirRegistro(tester);
    await llenar(tester);
    await enviar(tester);

    expect(find.text('Ya hay una cuenta con este documento.'), findsOneWidget);
    expect(find.byKey(const Key('mensaje-error')), findsNothing);
    expect(find.text('Registro de técnico o proveedor'), findsOneWidget);
  });

  testWidgets('muestra el correo repetido (409) junto a su campo', (
    tester,
  ) async {
    respuestaRegistro = () => respuestaJson({
      'type': 'https://quickpatch.internal/problems/correo-registrado',
      'title': 'Correo registrado',
      'status': 409,
    }, 409);
    await abrirRegistro(tester);
    await llenar(tester);
    await enviar(tester);

    expect(find.text('Ya hay una cuenta con este correo.'), findsOneWidget);
  });

  testWidgets('muestra los errores de validación del backend por campo', (
    tester,
  ) async {
    respuestaRegistro = () => respuestaJson({
      'type': 'https://quickpatch.internal/problems/validacion',
      'status': 400,
      'errors': {
        'phone': ['El teléfono no es válido.'],
        'specialtyId': ['La especialidad no existe.'],
      },
    }, 400);
    await abrirRegistro(tester);
    await llenar(tester);
    await enviar(tester);

    expect(find.text('El teléfono no es válido.'), findsOneWidget);
    expect(find.text('La especialidad no existe.'), findsOneWidget);
    expect(find.byKey(const Key('mensaje-error')), findsNothing);
  });

  testWidgets('muestra el tenant inactivo (403) como mensaje general', (
    tester,
  ) async {
    respuestaRegistro = () => respuestaJson({
      'type': 'https://quickpatch.internal/problems/tenant-inactivo',
      'status': 403,
    }, 403);
    await abrirRegistro(tester);
    await llenar(tester);
    await enviar(tester);

    expect(find.byKey(const Key('mensaje-error')), findsOneWidget);
  });

  testWidgets('sin categorías públicas muestra el error y permite reintentar', (
    tester,
  ) async {
    respuestaCategorias = () => respuestaJson({
      'type': 'https://quickpatch.internal/problems/no-autenticado',
      'status': 401,
    }, 401);
    await abrirRegistro(tester);

    expect(find.byKey(const Key('error-especialidades')), findsOneWidget);
    respuestaCategorias = categoriasOk;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Plomería'), findsOneWidget);
  });

  testWidgets('avisa cuando el tenant no tiene especialidades', (tester) async {
    respuestaCategorias = () => respuestaJson(<dynamic>[], 200);
    await abrirRegistro(tester);

    expect(find.byKey(const Key('sin-especialidades')), findsOneWidget);
  });

  testWidgets('no se desborda con el texto al 200 % (AC4-E7)', (tester) async {
    await abrirRegistro(tester, escalaTexto: 2);
    expect(tester.takeException(), isNull);
    await enviar(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('funciona con el tema oscuro', (tester) async {
    await abrirRegistro(tester, brillo: Brightness.dark);
    expect(tester.takeException(), isNull);
    expect(find.text('Plomería'), findsOneWidget);
  });
}
