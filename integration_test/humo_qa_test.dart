import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:quickpatch_mobile/app/app.dart';
import 'package:quickpatch_mobile/core/network/cliente_api.dart';

/// Prueba de humo de la app contra QA (SCRUM-448): la app real, en un emulador, con la configuración de QA.
///
/// Un cliente nuevo inicia sesión, crea una solicitud sin GPS (la app ubica la dirección y pregunta «¿Es aquí?»), ve
/// que se busca técnico y la cancela (SCRUM-477). Cada paso imprime su tiempo para el informe de pruebas.
///
/// Uso, con el emulador encendido:
///   flutter test integration_test/humo_qa_test.dart --dart-define-from-file=config/qa.json
/// La cuenta de prueba se crea en cada corrida con una clave aleatoria que no se guarda.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final tiempos = <String, Duration>{};

  /// Bombea hasta que [buscado] aparezca. No usa pumpAndSettle: el canal en tiempo real y la consulta de respaldo
  /// mantienen temporizadores vivos y la pantalla nunca queda quieta.
  Future<void> esperar(
    WidgetTester tester,
    Finder buscado,
    String paso, {
    int segundos = 30,
  }) async {
    final reloj = Stopwatch()..start();
    while (reloj.elapsed < Duration(seconds: segundos)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (buscado.evaluate().isNotEmpty) {
        tiempos[paso] = reloj.elapsed;
        debugPrint('OK    $paso (${reloj.elapsedMilliseconds} ms)');
        return;
      }
    }
    debugPrint('FALLO $paso (sin respuesta en $segundos s)');
    fail('$paso: no apareció $buscado en $segundos s');
  }

  Future<void> tocar(WidgetTester tester, Finder objetivo) async {
    await tester.ensureVisible(objetivo);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(objetivo);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('cliente: inicia sesión, crea una solicitud y la cancela en QA', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final api = container.read(clienteApiProvider);

    // Cuenta de prueba de esta corrida (el registro por la app ya lo cubren sus pruebas de widget).
    final sufijo = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final correo = 'humo448.$sufijo@quickpatch.test';
    final clave = 'Qp${Random.secure().nextInt(1 << 31).toRadixString(36)}7Z';
    final registro = await api.post<Map<String, dynamic>>(
      '/v1/auth/register/client',
      data: {'email': correo, 'password': clave, 'fullName': 'Humo 448'},
    );
    expect(registro.statusCode, 201);
    final categorias = await api.get<List<dynamic>>('/v1/catalog/categories');
    final categoria =
        (categorias.data!.first as Map<String, dynamic>)['name'] as String;
    debugPrint('Cliente de prueba: $correo; categoría: $categoria');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QuickpatchApp(),
      ),
    );
    await esperar(
      tester,
      find.byKey(const Key('campo-email')),
      'Pantalla de inicio de sesión',
    );

    await tester.enterText(find.byKey(const Key('campo-email')), correo);
    await tester.enterText(find.byKey(const Key('campo-password')), clave);
    await tocar(tester, find.byKey(const Key('boton-ingresar')));
    await esperar(
      tester,
      find.text('Nueva solicitud'),
      'Inicio de sesión del cliente (Identity)',
    );

    await tocar(tester, find.text('Nueva solicitud'));
    await esperar(
      tester,
      find.byKey(const Key('campo-categoria')),
      'Formulario con las categorías de Catalog',
    );
    await tocar(tester, find.byKey(const Key('campo-categoria')));
    await esperar(tester, find.text(categoria).last, 'Lista de categorías');
    await tocar(tester, find.text(categoria).last);
    await tester.enterText(
      find.byKey(const Key('campo-descripcion')),
      'Prueba de humo de la app contra QA (SCRUM-448)',
    );
    await tester.enterText(
      find.byKey(const Key('campo-direccion')),
      'Calle 63 # 9-45, Bogotá',
    );

    // Sin compartir el GPS: ServiceRequest ubica la dirección con Nominatim (location-preview, ADR-024).
    await tocar(tester, find.byKey(const Key('boton-enviar')));
    await esperar(
      tester,
      find.byKey(const Key('boton-si-es-aqui')),
      '«¿Es aquí?» con la dirección ubicada',
    );
    await tocar(tester, find.byKey(const Key('boton-si-es-aqui')));
    await esperar(
      tester,
      find.byKey(const Key('estado-solicitud')),
      'Solicitud creada y detalle abierto',
    );

    final estado = tester
        .widget<Text>(find.byKey(const Key('estado-solicitud')))
        .data;
    debugPrint('Estado inicial: $estado');
    expect(estado, anyOf('Buscando técnico', 'En espera'));

    // El botón está al final de la lista del detalle, que construye sus hijos al desplazarse.
    await tester.scrollUntilVisible(
      find.byKey(const Key('boton-cancelar-solicitud')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tocar(tester, find.byKey(const Key('boton-cancelar-solicitud')));
    await esperar(
      tester,
      find.byKey(const Key('campo-motivo-cancelacion')),
      'Diálogo de cancelación',
    );
    await tester.enterText(
      find.byKey(const Key('campo-motivo-cancelacion')),
      'Prueba de humo terminada.',
    );
    await tocar(tester, find.byKey(const Key('confirmar-cancelacion')));
    await esperar(
      tester,
      find.byKey(const Key('tarjeta-cancelacion')),
      'Solicitud cancelada con su motivo',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('estado-solicitud'))).data,
      'Cancelada',
    );

    debugPrint(
      'Tiempos: ${tiempos.map((k, v) => MapEntry(k, '${v.inMilliseconds} ms'))}',
    );
  });
}
