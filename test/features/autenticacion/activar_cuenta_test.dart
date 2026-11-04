import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/app.dart';
import 'package:quickpatch_mobile/app/router/app_router.dart';
import 'package:quickpatch_mobile/core/network/cliente_api.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/features/autenticacion/presentation/paginas/inicio_sesion_page.dart';

import '../../helpers/fakes.dart';

/// SCRUM-98: el técnico del equipo de un proveedor define su contraseña con
/// la invitación (`POST /v1/auth/password/setup`, identity 1.7.0).
void main() {
  const token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJ012-_56';
  const enlace = 'https://quickpatch.internal/activar#token=$token';
  late List<RequestOptions> peticiones;
  late ResponseBody Function() respuesta;

  setUp(() {
    peticiones = [];
    respuesta = () => ResponseBody.fromString('', 204);
  });

  Future<ProviderContainer> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
      ],
    );
    addTearDown(container.dispose);
    container.read(clienteApiProvider).httpClientAdapter = AdaptadorFalso((o) {
      peticiones.add(o);
      return respuesta();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QuickpatchApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> escribir(WidgetTester tester, String clave, String texto) async {
    await tester.enterText(find.byKey(Key(clave)), texto);
    await tester.pump();
  }

  Future<void> tocar(WidgetTester tester, Finder objetivo) async {
    await tester.ensureVisible(objetivo);
    await tester.tap(objetivo);
    await tester.pumpAndSettle();
  }

  Future<void> definir(WidgetTester tester, String password) async {
    await escribir(tester, 'campo-password', password);
    await escribir(tester, 'campo-confirmacion', password);
    await tocar(tester, find.byKey(const Key('boton-activar')));
  }

  Iterable<RequestOptions> envios() =>
      peticiones.where((p) => p.path.endsWith('/v1/auth/password/setup'));

  testWidgets('desde el login pega el enlace y activa la cuenta', (
    tester,
  ) async {
    await abrir(tester);
    await tocar(tester, find.byKey(const Key('boton-ir-activar')));
    expect(find.text('Activa tu cuenta'), findsWidgets);

    // Sin enlace válido no envía nada.
    await escribir(tester, 'campo-enlace', 'hola, te mando el enlace');
    await definir(tester, 'Segura.2026');
    expect(
      find.text('Pega el enlace completo que te compartió tu proveedor.'),
      findsOneWidget,
    );
    expect(envios(), isEmpty);

    await escribir(tester, 'campo-enlace', '  $enlace ');
    await tocar(tester, find.byKey(const Key('boton-activar')));

    final envio = envios().single;
    expect(envio.method, 'POST');
    expect(envio.data, {'token': token, 'password': 'Segura.2026'});
    expect(envio.headers['Authorization'], isNull);
    expect(envio.headers['X-Channel-Id'], isNotNull);
    expect(find.byKey(const Key('cuenta-activada')), findsOneWidget);

    await tocar(tester, find.text('Iniciar sesión'));
    expect(find.byType(InicioSesionPage), findsOneWidget);
  });

  testWidgets('el enlace abre la pantalla con el token, sin pedirlo', (
    tester,
  ) async {
    final container = await abrir(tester);
    container.read(routerProvider).go('/activar#token=$token');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('campo-enlace')), findsNothing);
    await definir(tester, 'Segura.2026');
    expect((envios().single.data as Map)['token'], token);
    expect(find.byKey(const Key('cuenta-activada')), findsOneWidget);
  });

  testWidgets('valida la contraseña y su confirmación antes de enviar', (
    tester,
  ) async {
    final container = await abrir(tester);
    container.read(routerProvider).go('/activar#token=$token');
    await tester.pumpAndSettle();

    await escribir(tester, 'campo-password', 'corta');
    await escribir(tester, 'campo-confirmacion', 'otra');
    await tocar(tester, find.byKey(const Key('boton-activar')));
    expect(find.text('Usa al menos 8 caracteres.'), findsOneWidget);
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(envios(), isEmpty);
  });

  testWidgets('un enlace usado o vencido pide uno nuevo al proveedor', (
    tester,
  ) async {
    respuesta = () => respuestaJson({
      'type': 'https://quickpatch.internal/problems/enlace-invalido',
      'status': 400,
    }, 400);
    final container = await abrir(tester);
    container.read(routerProvider).go('/activar#token=$token');
    await tester.pumpAndSettle();

    await definir(tester, 'Segura.2026');
    expect(find.byKey(const Key('mensaje-error')), findsOneWidget);
    expect(find.textContaining('Pide a tu proveedor'), findsOneWidget);
    expect(find.byKey(const Key('cuenta-activada')), findsNothing);
  });

  testWidgets('el 400 de la contraseña queda junto al campo', (tester) async {
    respuesta = () => respuestaJson({
      'type': 'https://quickpatch.internal/problems/validacion',
      'status': 400,
      'errors': {
        'password': ['La contraseña no cumple la política.'],
      },
    }, 400);
    final container = await abrir(tester);
    container.read(routerProvider).go('/activar#token=$token');
    await tester.pumpAndSettle();

    await definir(tester, 'Segura.2026');
    expect(find.text('La contraseña no cumple la política.'), findsOneWidget);
    expect(find.byKey(const Key('mensaje-error')), findsNothing);
  });

  testWidgets('sin conexión muestra el error general', (tester) async {
    respuesta = () => throw DioException.connectionError(
      requestOptions: RequestOptions(),
      reason: 'sin red',
    );
    final container = await abrir(tester);
    container.read(routerProvider).go('/activar#token=$token');
    await tester.pumpAndSettle();

    await definir(tester, 'Segura.2026');
    expect(find.text('No hay conexión con QUICKPATCH.'), findsOneWidget);
  });
}
