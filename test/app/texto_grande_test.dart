import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/app.dart';
import 'package:quickpatch_mobile/app/router/app_router.dart';
import 'package:quickpatch_mobile/app/router/rutas.dart';
import 'package:quickpatch_mobile/core/network/cliente_api.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';

import '../helpers/fakes.dart';

/// AC4-E7: con el texto al 200 % las pantallas rediseñadas (SCRUM-442) no se
/// desbordan; el contenido se desplaza.
void main() {
  late ProviderContainer container;

  Future<void> abrir(WidgetTester tester, {bool conSesion = false}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final memoria = AlmacenSeguroEnMemoria();
    if (conSesion) await AlmacenSesion(memoria).guardar(sesionDePrueba());
    container = ProviderContainer(
      overrides: [almacenSeguroProvider.overrideWithValue(memoria)],
    );
    addTearDown(container.dispose);
    container.read(clienteApiProvider).httpClientAdapter = AdaptadorFalso(
      (_) => respuestaJson([
        {'id': 'c-1', 'name': 'Electrodomésticos'},
        {'id': 'c-2', 'name': 'Aire acondicionado'},
      ], 200),
    );
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

  testWidgets('inicio de sesión y registro', (tester) async {
    await abrir(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('boton-ingresar')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await ir(tester, Rutas.registro);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nueva solicitud', (tester) async {
    await abrir(tester, conSesion: true);
    await ir(tester, Rutas.nuevaSolicitudEn('c-1'));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('boton-enviar')));
    await tester.tap(find.byKey(const Key('boton-enviar')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
