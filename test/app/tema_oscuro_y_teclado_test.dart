import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/app.dart';
import 'package:quickpatch_mobile/app/router/app_router.dart';
import 'package:quickpatch_mobile/app/router/rutas.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/core/network/cliente_api.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';

import '../helpers/fakes.dart';

/// SCRUM-444: las pantallas rediseñadas también funcionan en tema oscuro y
/// los formularios se envían con la tecla "listo" del teclado.
void main() {
  late ProviderContainer container;
  late List<RequestOptions> peticiones;

  Future<void> abrir(
    WidgetTester tester, {
    RolUsuario? rol,
    Brightness brillo = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.platformBrightnessTestValue = brillo;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final memoria = AlmacenSeguroEnMemoria();
    if (rol != null) {
      await AlmacenSesion(memoria).guardar(sesionDePrueba(rol: rol));
    }
    peticiones = [];
    container = ProviderContainer(
      overrides: [almacenSeguroProvider.overrideWithValue(memoria)],
    );
    addTearDown(container.dispose);
    container.read(clienteApiProvider).httpClientAdapter = AdaptadorFalso((o) {
      peticiones.add(o);
      if (o.path.endsWith('/categories')) {
        return respuestaJson([
          {'id': 'c-1', 'name': 'Plomería'},
        ], 200);
      }
      if (o.path.endsWith('/login')) return respuestaJson(loginJson(), 200);
      if (o.path == '/v1/technicians/me/service-requests' ||
          o.path == '/v1/service-requests' && o.method == 'GET' ||
          o.path == '/v1/matching/offers') {
        return respuestaJson({
          'items': <dynamic>[],
          'page': 1,
          'size': 20,
          'totalItems': 0,
        }, 200);
      }
      return respuestaJson({'userId': 'u', 'role': 'cliente'}, 201);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QuickpatchApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> ir(WidgetTester tester, String ruta) async {
    container.read(routerProvider).go(ruta);
    await tester.pumpAndSettle();
  }

  group('tema oscuro', () {
    testWidgets('inicio de sesión y registro', (tester) async {
      await abrir(tester, brillo: Brightness.dark);
      final contexto = tester.element(find.byKey(const Key('boton-ingresar')));
      expect(Theme.of(contexto).colorScheme, AppTheme.esquemaOscuro);
      expect(tester.takeException(), isNull);

      await ir(tester, Rutas.registro);
      expect(tester.takeException(), isNull);
    });

    for (final rol in [RolUsuario.cliente, RolUsuario.tecnico]) {
      testWidgets('pestañas del ${rol.valor}', (tester) async {
        await abrir(tester, rol: rol, brillo: Brightness.dark);
        for (final ruta in [Rutas.inicio, Rutas.actividad, Rutas.cuenta]) {
          await ir(tester, ruta);
          expect(tester.takeException(), isNull, reason: ruta);
        }
      });
    }

    testWidgets('nueva solicitud', (tester) async {
      await abrir(tester, rol: RolUsuario.cliente, brillo: Brightness.dark);
      await ir(tester, Rutas.nuevaSolicitudEn('c-1'));
      expect(find.text('Plomería'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('envío con el teclado', () {
    testWidgets('"listo" en la contraseña inicia sesión', (tester) async {
      await abrir(tester);
      await tester.enterText(
        find.byKey(const Key('campo-email')),
        'ana@correo.com',
      );
      await tester.enterText(
        find.byKey(const Key('campo-password')),
        'secreta123',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(peticiones.any((o) => o.path.endsWith('/login')), isTrue);
      expect(find.text('Hola, Ana Gómez'), findsOneWidget);
    });

    testWidgets('"listo" en la confirmación envía el registro', (tester) async {
      await abrir(tester);
      await ir(tester, Rutas.registro);
      await tester.enterText(find.byKey(const Key('campo-nombre')), 'Ana');
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
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        peticiones.map((o) => o.path),
        containsAllInOrder(['/v1/auth/register/client', '/v1/auth/login']),
      );
    });
  });
}
