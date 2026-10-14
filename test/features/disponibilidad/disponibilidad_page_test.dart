import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/app.dart';
import 'package:quickpatch_mobile/app/router/app_router.dart';
import 'package:quickpatch_mobile/app/router/rutas.dart';
import 'package:quickpatch_mobile/core/network/cliente_api.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';

import '../../helpers/fakes.dart';

/// SCRUM-89: disponibilidad y zona de cobertura del técnico.
void main() {
  late List<RequestOptions> peticiones;
  late String estado;
  late List<String> cubiertas;
  late ResponseBody Function()? respuestaPutDisponibilidad;
  late ResponseBody Function()? respuestaPutCobertura;
  late ResponseBody Function()? respuestaGetDisponibilidad;
  late ResponseBody Function()? respuestaLocalidades;

  const localidades = [
    {'code': '01', 'name': 'Usaquén'},
    {'code': '02', 'name': 'Chapinero'},
    {'code': '03', 'name': 'Santa Fe'},
  ];
  String nombreDe(String codigo) =>
      localidades.firstWhere((l) => l['code'] == codigo)['name']!;

  Map<String, dynamic> disponibilidadJson() => {
    'status': estado,
    'updatedAt': '2026-10-12T15:00:00Z',
  };
  Map<String, dynamic> coberturaJson() => {
    'localities': [
      for (final c in cubiertas) {'code': c, 'name': nombreDe(c)},
    ],
  };

  setUp(() {
    peticiones = [];
    estado = 'no_disponible';
    cubiertas = ['02'];
    respuestaPutDisponibilidad = null;
    respuestaPutCobertura = null;
    respuestaGetDisponibilidad = null;
    respuestaLocalidades = null;
  });

  AdaptadorFalso adaptador() => AdaptadorFalso((o) {
    peticiones.add(o);
    final ruta = o.path;
    if (ruta.endsWith('/v1/localities')) {
      return respuestaLocalidades?.call() ?? respuestaJson(localidades, 200);
    }
    if (ruta.endsWith('/v1/technicians/me/availability')) {
      if (o.method == 'PUT') {
        final r = respuestaPutDisponibilidad?.call();
        if (r != null) return r;
        estado = (o.data as Map)['status'] as String;
      } else if (respuestaGetDisponibilidad != null) {
        return respuestaGetDisponibilidad!();
      }
      return respuestaJson(disponibilidadJson(), 200);
    }
    if (ruta.endsWith('/v1/technicians/me/coverage')) {
      if (o.method == 'PUT') {
        final r = respuestaPutCobertura?.call();
        if (r != null) return r;
        cubiertas = ((o.data as Map)['localityCodes'] as List).cast<String>();
      }
      return respuestaJson(coberturaJson(), 200);
    }
    return respuestaJson(<String, dynamic>{}, 404);
  });

  Future<void> abrir(
    WidgetTester tester, {
    double escalaTexto = 1,
    Brightness brillo = Brightness.light,
    bool directo = true,
  }) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = escalaTexto;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = brillo;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final memoria = AlmacenSeguroEnMemoria();
    await AlmacenSesion(memoria)
        .guardar(sesionDePrueba(rol: RolUsuario.tecnico));
    final container = ProviderContainer(
      overrides: [almacenSeguroProvider.overrideWithValue(memoria)],
    );
    addTearDown(container.dispose);
    container.read(clienteApiProvider).httpClientAdapter = adaptador();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QuickpatchApp(),
      ),
    );
    await tester.pumpAndSettle();
    if (directo) {
      unawaited(container.read(routerProvider).push(Rutas.disponibilidad));
      await tester.pumpAndSettle();
    }
  }

  Iterable<RequestOptions> puts(String final_) =>
      peticiones.where((p) => p.method == 'PUT' && p.path.endsWith(final_));

  Future<void> tocar(WidgetTester tester, Finder objetivo) async {
    await tester.ensureVisible(objetivo);
    await tester.tap(objetivo);
    await tester.pumpAndSettle();
  }

  testWidgets('el inicio del técnico abre la pantalla', (tester) async {
    await abrir(tester, directo: false);
    await tocar(tester, find.text('Disponibilidad y cobertura'));
    expect(find.text('Disponibilidad y cobertura'), findsOneWidget);
    expect(find.text('Tu disponibilidad'), findsOneWidget);
    expect(find.text('Tus localidades'), findsOneWidget);
  });

  testWidgets('muestra el estado y la cobertura guardados', (tester) async {
    await abrir(tester);

    expect(find.byKey(const Key('estado-no_disponible')), findsOneWidget);
    final interruptor = tester.widget<SwitchListTile>(
      find.byKey(const Key('interruptor-disponibilidad')),
    );
    expect(interruptor.value, isFalse);
    final chapinero = tester.widget<FilterChip>(
      find.byKey(const Key('localidad-02')),
    );
    expect(chapinero.selected, isTrue);
    expect(find.text('1 de 3 seleccionadas'), findsOneWidget);

    final localidadesPublicas = peticiones.firstWhere(
      (p) => p.path.endsWith('/v1/localities'),
    );
    expect(localidadesPublicas.headers['Authorization'], isNull);
    expect(localidadesPublicas.headers['X-Channel-Id'], isNotNull);
  });

  testWidgets('pasa a disponible con PUT availability', (tester) async {
    await abrir(tester);
    await tocar(tester, find.byKey(const Key('interruptor-disponibilidad')));

    final put = puts('/v1/technicians/me/availability').single;
    expect(put.data, {'status': 'disponible'});
    expect((put.data as Map).containsKey('tenantId'), isFalse);
    expect(find.byKey(const Key('estado-disponible')), findsOneWidget);
  });

  testWidgets('ocupado: el interruptor queda bloqueado (RN-M6)', (
    tester,
  ) async {
    estado = 'ocupado';
    await abrir(tester);

    final interruptor = tester.widget<SwitchListTile>(
      find.byKey(const Key('interruptor-disponibilidad')),
    );
    expect(interruptor.onChanged, isNull);
    expect(find.byKey(const Key('aviso-ocupado')), findsOneWidget);
    expect(find.byKey(const Key('estado-ocupado')), findsOneWidget);
  });

  testWidgets('un 409 al cambiar explica que está ocupado', (tester) async {
    respuestaPutDisponibilidad = () => respuestaJson({
      'type': 'https://quickpatch.internal/problems/transicion-invalida',
      'status': 409,
    }, 409);
    await abrir(tester);
    await tocar(tester, find.byKey(const Key('interruptor-disponibilidad')));

    expect(find.byKey(const Key('error-disponibilidad')), findsOneWidget);
    expect(find.textContaining('Estás atendiendo un servicio'), findsOneWidget);
    expect(find.byKey(const Key('estado-no_disponible')), findsOneWidget);
  });

  testWidgets('guarda las localidades elegidas con PUT coverage', (
    tester,
  ) async {
    await abrir(tester);
    await tocar(tester, find.byKey(const Key('localidad-01')));
    await tocar(tester, find.byKey(const Key('localidad-03')));
    expect(find.text('3 de 3 seleccionadas'), findsOneWidget);
    await tocar(tester, find.byKey(const Key('boton-guardar-cobertura')));

    expect(puts('/v1/technicians/me/coverage').single.data, {
      'localityCodes': ['01', '02', '03'],
    });
    expect(find.text('Guardamos tus localidades.'), findsOneWidget);
    expect(find.text('No hay cambios por guardar.'), findsOneWidget);
  });

  testWidgets('sin cambios el botón no envía nada', (tester) async {
    await abrir(tester);
    expect(find.text('No hay cambios por guardar.'), findsOneWidget);
    await tocar(tester, find.byKey(const Key('boton-guardar-cobertura')));
    expect(puts('/v1/technicians/me/coverage'), isEmpty);
  });

  testWidgets('exige al menos una localidad antes de enviar', (tester) async {
    await abrir(tester);
    await tocar(tester, find.byKey(const Key('localidad-02')));
    await tocar(tester, find.byKey(const Key('boton-guardar-cobertura')));

    expect(find.text('Elige al menos una localidad.'), findsOneWidget);
    expect(puts('/v1/technicians/me/coverage'), isEmpty);
  });

  testWidgets('muestra el 400 de la cobertura', (tester) async {
    respuestaPutCobertura = () => respuestaJson({
      'type': 'https://quickpatch.internal/problems/validacion',
      'status': 400,
      'errors': {
        'localityCodes': ['La localidad 99 no existe.'],
      },
    }, 400);
    await abrir(tester);
    await tocar(tester, find.byKey(const Key('localidad-01')));
    await tocar(tester, find.byKey(const Key('boton-guardar-cobertura')));

    expect(find.text('La localidad 99 no existe.'), findsOneWidget);
  });

  testWidgets('404: la cuenta aún se está preparando y permite reintentar', (
    tester,
  ) async {
    respuestaGetDisponibilidad = () => respuestaJson({
      'type': 'https://quickpatch.internal/problems/no-encontrado',
      'status': 404,
    }, 404);
    await abrir(tester);

    expect(find.byKey(const Key('cuenta-en-preparacion')), findsOneWidget);
    respuestaGetDisponibilidad = null;
    await tocar(tester, find.text('Reintentar'));
    expect(find.byKey(const Key('estado-no_disponible')), findsOneWidget);
  });

  testWidgets('error al cargar las localidades con reintento', (tester) async {
    respuestaLocalidades = () => ResponseBody.fromString(
      jsonEncode({'status': 503}),
      503,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
    await abrir(tester);

    expect(find.byKey(const Key('error-carga')), findsOneWidget);
    respuestaLocalidades = null;
    await tocar(tester, find.text('Reintentar'));
    expect(find.byKey(const Key('localidad-01')), findsOneWidget);
  });

  testWidgets('sin localidades muestra un estado vacío', (tester) async {
    respuestaLocalidades = () => respuestaJson(<dynamic>[], 200);
    await abrir(tester);
    expect(find.byKey(const Key('sin-localidades')), findsOneWidget);
  });

  testWidgets('no se desborda con el texto al 200 % (AC4-E7)', (tester) async {
    estado = 'ocupado';
    await abrir(tester, escalaTexto: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('funciona con el tema oscuro', (tester) async {
    await abrir(tester, brillo: Brightness.dark);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('estado-no_disponible')), findsOneWidget);
  });
}
