import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/app.dart';
import 'package:quickpatch_mobile/app/router/app_router.dart';
import 'package:quickpatch_mobile/app/router/rutas.dart';
import 'package:quickpatch_mobile/core/network/cliente_api.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';
import 'package:quickpatch_mobile/core/session/sesion.dart';
import 'package:quickpatch_mobile/features/autenticacion/presentation/paginas/inicio_sesion_page.dart';

import '../helpers/fakes.dart';

void main() {
  late AlmacenSeguroEnMemoria memoria;
  late AdaptadorFalso adaptador;
  late ProviderContainer container;

  Future<void> abrirApp(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [almacenSeguroProvider.overrideWithValue(memoria)],
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
  }

  setUp(() {
    memoria = AlmacenSeguroEnMemoria();
    adaptador = AdaptadorFalso((_) => respuestaJson(loginJson(), 200));
  });

  testWidgets('flujo completo: login, inicio del cliente y salida', (
    tester,
  ) async {
    await abrirApp(tester);
    expect(find.byType(InicioSesionPage), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('campo-email')),
      'ana@correo.com',
    );
    await tester.enterText(find.byKey(const Key('campo-password')), 'secreta');
    await tester.tap(find.byKey(const Key('boton-ingresar')));
    await tester.pumpAndSettle();

    expect(adaptador.ultima!.headers['X-Channel-Id'], 'quickpatch-mobile');
    expect(find.text('Hola, Ana Gómez'), findsOneWidget);
    expect(find.text('Nueva solicitud'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton-salir')));
    await tester.pumpAndSettle();
    expect(find.byType(InicioSesionPage), findsOneWidget);
  });

  testWidgets('valida el formulario antes de enviar', (tester) async {
    await abrirApp(tester);
    await tester.tap(find.byKey(const Key('boton-ingresar')));
    await tester.pump();
    expect(find.text('Escribe tu correo.'), findsOneWidget);
    expect(find.text('Escribe tu contraseña.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo-email')), 'ana');
    await tester.tap(find.byKey(const Key('boton-ingresar')));
    await tester.pump();
    expect(find.textContaining('correo válido'), findsOneWidget);
    expect(adaptador.ultima, isNull);
  });

  testWidgets('muestra el mensaje del código de error', (tester) async {
    adaptador.responder = (_) =>
        respuestaJson({'status': 401, 'code': 'INVALID_CREDENTIALS'}, 401);
    await abrirApp(tester);
    await tester.enterText(
      find.byKey(const Key('campo-email')),
      'ana@correo.com',
    );
    await tester.enterText(find.byKey(const Key('campo-password')), 'mala');
    await tester.tap(find.byKey(const Key('boton-ingresar')));
    await tester.pumpAndSettle();
    expect(
      find.text('El correo o la contraseña no son correctos.'),
      findsOneWidget,
    );
  });

  testWidgets('sesión guardada de admin entra con aviso del panel web', (
    tester,
  ) async {
    await AlmacenSesion(memoria)
        .guardar(sesionDePrueba(rol: RolUsuario.adminTenant));
    await abrirApp(tester);
    expect(find.byKey(const Key('mensaje-admin')), findsOneWidget);
  });

  testWidgets('registro de hogar inicia sesión y muestra el inicio', (
    tester,
  ) async {
    final rutas = <String>[];
    adaptador.responder = (o) {
      rutas.add(o.path);
      return o.path.endsWith('/login')
          ? respuestaJson(loginJson(), 200)
          : respuestaJson({'userId': 'u', 'role': 'cliente'}, 201);
    };
    await abrirApp(tester);
    await tester.tap(find.byKey(const Key('boton-ir-registro')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('campo-nombre')), 'Ana Gómez');
    await tester.enterText(
      find.byKey(const Key('campo-email')),
      'ana@correo.com',
    );
    await tester.enterText(
      find.byKey(const Key('campo-password')),
      'secreta123',
    );
    await tester.enterText(
      find.byKey(const Key('campo-confirmacion')),
      'secreta123',
    );
    await tester.ensureVisible(find.byKey(const Key('boton-registrar')));
    await tester.tap(find.byKey(const Key('boton-registrar')));
    await tester.pumpAndSettle();

    expect(rutas, ['/v1/auth/register/client', '/v1/auth/login']);
    expect(find.text('Hola, Ana Gómez'), findsOneWidget);
  });

  testWidgets(
    'registro de cliente valida, muestra el error del contrato y oculta empresa',
    (tester) async {
      adaptador.responder = (_) => respuestaJson({
        'type': 'https://quickpatch.internal/problems/validacion',
        'title': 'La solicitud tiene datos inválidos',
        'status': 400,
        'errors': {
          'email': ['El correo no tiene un formato válido.'],
        },
      }, 400);
      await abrirApp(tester);
      await tester.tap(find.byKey(const Key('boton-ir-registro')));
      await tester.pumpAndSettle();
      expect(find.text('Empresa'), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('boton-registrar')));
      await tester.tap(find.byKey(const Key('boton-registrar')));
      await tester.pumpAndSettle();
      expect(adaptador.ultima, isNull);

      await tester.enterText(find.byKey(const Key('campo-nombre')), 'Ana');
      await tester.enterText(find.byKey(const Key('campo-email')), 'a@e.co');
      await tester.enterText(
        find.byKey(const Key('campo-password')),
        'secreta123',
      );
      await tester.enterText(
        find.byKey(const Key('campo-confirmacion')),
        'secreta123',
      );
      await tester.ensureVisible(find.byKey(const Key('boton-registrar')));
      await tester.tap(find.byKey(const Key('boton-registrar')));
      await tester.pumpAndSettle();
      expect(adaptador.ultima!.path, '/v1/auth/register/client');
      expect(
        find.text('El correo no tiene un formato válido.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('mensaje-error')), findsOneWidget);

      await tester.ensureVisible(find.text('Ya tengo cuenta'));
      await tester.tap(find.text('Ya tengo cuenta'));
      await tester.pumpAndSettle();
      expect(find.byType(InicioSesionPage), findsOneWidget);
    },
  );

  group('calcularRedireccion', () {
    final sesion = sesionDePrueba();

    test('mientras carga va a la pantalla de carga', () {
      const cargando = AsyncLoading<Sesion?>();
      expect(calcularRedireccion(cargando, Rutas.inicio), Rutas.cargando);
      expect(calcularRedireccion(cargando, Rutas.cargando), isNull);
    });

    test('sin sesión va al login, pero puede registrarse', () {
      const sin = AsyncData<Sesion?>(null);
      expect(calcularRedireccion(sin, Rutas.inicio), Rutas.iniciarSesion);
      expect(calcularRedireccion(sin, Rutas.iniciarSesion), isNull);
      expect(calcularRedireccion(sin, Rutas.registro), isNull);
    });

    test('con sesión sale de las pantallas de entrada', () {
      final con = AsyncData<Sesion?>(sesion);
      expect(calcularRedireccion(con, Rutas.iniciarSesion), Rutas.inicio);
      expect(calcularRedireccion(con, Rutas.cargando), Rutas.inicio);
      expect(calcularRedireccion(con, Rutas.registro), Rutas.inicio);
      expect(calcularRedireccion(con, Rutas.inicio), isNull);
    });
  });
}
