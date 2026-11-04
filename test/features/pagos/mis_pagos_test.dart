import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/app.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/core/catalogo/repositorio_catalogo.dart';
import 'package:quickpatch_mobile/core/geo/repositorio_localidades.dart';
import 'package:quickpatch_mobile/core/network/cliente_api.dart';
import 'package:quickpatch_mobile/core/realtime/canal_tiempo_real.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';
import 'package:quickpatch_mobile/core/utils/fechas.dart';
import 'package:quickpatch_mobile/features/cuenta/presentation/paginas/cuenta_page.dart';
import 'package:quickpatch_mobile/features/equipo/data/repositorio_equipo.dart';
import 'package:quickpatch_mobile/features/pagos/domain/pago.dart';
import 'package:quickpatch_mobile/features/pagos/domain/pago_recibido.dart';
import 'package:quickpatch_mobile/features/pagos/presentation/paginas/mis_pagos_page.dart';

import '../../helpers/fakes.dart';

/// SCRUM-502: pagos recibidos del técnico y del equipo del proveedor, con
/// `GET /v1/payments/received` (payments 1.2.0).
const _ruta = '/v1/payments/received';
const _equipo = '/v1/providers/me/technicians';

Map<String, dynamic> _pago(
  String id, {
  String status = 'aprobado',
  String amount = '125000.00',
  String technicianId = 't-1',
}) => {
  'id': id,
  'serviceRequestId': 'sr-$id',
  'technicianId': technicianId,
  'amount': amount,
  'currency': 'COP',
  'status': status,
  'createdAt': '2026-10-20T14:10:00Z',
  'approvedAt': status == 'aprobado' ? '2026-10-20T14:30:00Z' : null,
};

Map<String, dynamic> _pagina(
  List<Map<String, dynamic>> items, {
  int page = 1,
  int? total,
}) => {
  'items': items,
  'page': page,
  'size': 20,
  'totalItems': total ?? items.length,
};

Map<String, dynamic> _tecnico(String id, String nombre) => {
  'userId': id,
  'fullName': nombre,
  'specialtyId': 'c-1',
  'verificationStatus': 'aprobado',
};

void main() {
  late List<RequestOptions> consultas;
  late List<RequestOptions> consultasEquipo;
  late ResponseBody Function(RequestOptions) responder;
  late ResponseBody Function(RequestOptions) responderEquipo;

  setUp(() {
    consultas = [];
    consultasEquipo = [];
    responder = (o) => respuestaJson(_pagina([_pago('p-1')]), 200);
    responderEquipo = (o) => respuestaJson(
      _pagina([_tecnico('t-1', 'Ana Ruiz'), _tecnico('t-2', 'Luis Mora')]),
      200,
    );
  });

  /// Abre la app con [rol] y va a la pestaña Cuenta.
  Future<void> abrirCuenta(
    WidgetTester tester, {
    RolUsuario rol = RolUsuario.tecnico,
    ThemeData? tema,
    double escalaTexto = 1,
  }) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = escalaTexto;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    if (tema != null) {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    }
    final memoria = AlmacenSeguroEnMemoria();
    await AlmacenSesion(memoria).guardar(sesionDePrueba(rol: rol));
    final container = ProviderContainer(
      // Sin reintentos automáticos: el error del equipo se ve en seguida.
      retry: (_, _) => null,
      overrides: [
        almacenSeguroProvider.overrideWithValue(memoria),
        conectorWsProvider.overrideWithValue(ConectorWsFalso().call),
        categoriasProvider.overrideWith((ref) async => const []),
        localidadesProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);
    container.read(clienteApiProvider).httpClientAdapter = AdaptadorFalso((o) {
      if (o.path == _ruta) {
        consultas.add(o);
        return responder(o);
      }
      if (o.path == _equipo) {
        consultasEquipo.add(o);
        return responderEquipo(o);
      }
      if (o.path == '/v1/matching/offers') {
        return respuestaJson(_pagina(const []), 200);
      }
      return respuestaJson(<String, dynamic>{}, 404);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QuickpatchApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('barra-navegacion')),
        matching: find.text('Cuenta'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder clave(String k) => find.byKey(Key(k));

  /// Abre Mis pagos desde Cuenta.
  Future<void> abrir(
    WidgetTester tester, {
    RolUsuario rol = RolUsuario.tecnico,
    ThemeData? tema,
    double escalaTexto = 1,
  }) async {
    await abrirCuenta(tester, rol: rol, tema: tema, escalaTexto: escalaTexto);
    consultas.clear();
    await tester.tap(clave('fila-mis-pagos'));
    await tester.pumpAndSettle();
  }

  /// Elige [nombre] en el selector de técnico del proveedor.
  Future<void> elegirTecnico(WidgetTester tester, String nombre) async {
    await tester.tap(clave('selector-tecnico'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(nombre).last);
    await tester.pumpAndSettle();
  }

  String fecha(String iso) => fechaCorta(DateTime.parse(iso).toLocal());

  testWidgets('solo el técnico y el proveedor ven Mis pagos en Cuenta', (
    tester,
  ) async {
    await abrirCuenta(tester, rol: RolUsuario.cliente);
    expect(find.byType(CuentaPage), findsOneWidget);
    expect(clave('fila-mis-pagos'), findsNothing);
  });

  testWidgets('el proveedor ve la fila con el texto de su equipo', (
    tester,
  ) async {
    await abrirCuenta(tester, rol: RolUsuario.proveedor);
    expect(find.text('Pagos de los técnicos de tu equipo'), findsOneWidget);
  });

  testWidgets('el técnico ve sus pagos y vuelve con la flecha', (tester) async {
    await abrir(tester);

    expect(find.byType(MisPagosPage), findsOneWidget);
    expect(consultas.single.queryParameters, {'page': 1, 'size': 20});
    expect(find.text('1 pago'), findsOneWidget);
    expect(find.text(r'$ 125.000'), findsOneWidget);
    expect(find.text('Recibido'), findsOneWidget);
    expect(
      find.text('Recibido el ${fecha('2026-10-20T14:30:00Z')}'),
      findsOneWidget,
    );
    // El técnico no ve selector ni nombres, ni se consulta el equipo.
    expect(clave('selector-tecnico'), findsNothing);
    expect(consultasEquipo, isEmpty);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(CuentaPage), findsOneWidget);
  });

  testWidgets('un pago sin aprobar muestra cuándo se completó el servicio', (
    tester,
  ) async {
    responder = (o) => respuestaJson(
      _pagina([
        _pago('p-1', status: 'pendiente', amount: '80000.50'),
        _pago('p-2', status: 'procesando'),
      ]),
      200,
    );
    await abrir(tester);

    expect(find.text(r'$ 80.000,50'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('Procesando'), findsNWidgets(2));
    expect(
      find.text('Servicio completado el ${fecha('2026-10-20T14:10:00Z')}'),
      findsNWidgets(2),
    );
  });

  testWidgets('cada filtro consulta su estado', (tester) async {
    await abrir(tester);

    await tester.tap(clave('filtro-pendientes'));
    await tester.pumpAndSettle();
    expect(consultas.last.queryParameters['status'], 'pendiente');

    await tester.tap(clave('filtro-procesando'));
    await tester.pumpAndSettle();
    expect(consultas.last.queryParameters['status'], 'procesando');

    await tester.tap(clave('filtro-recibidos'));
    await tester.pumpAndSettle();
    expect(consultas.last.queryParameters['status'], 'aprobado');

    final antes = consultas.length;
    await tester.tap(clave('filtro-recibidos'));
    await tester.pumpAndSettle();
    expect(consultas.length, antes);

    await tester.tap(clave('filtro-todos'));
    await tester.pumpAndSettle();
    expect(consultas.last.queryParameters.containsKey('status'), isFalse);
  });

  testWidgets('el proveedor ve el nombre del técnico de cada pago', (
    tester,
  ) async {
    responder = (o) => respuestaJson(
      _pagina([
        _pago('p-1'),
        _pago('p-2', technicianId: 't-2'),
        _pago('p-3', technicianId: 't-9'),
      ]),
      200,
    );
    await abrir(tester, rol: RolUsuario.proveedor);

    expect(find.text('Ana Ruiz'), findsOneWidget);
    expect(find.text('Luis Mora'), findsOneWidget);
    // Un técnico que ya no está en la lista del equipo.
    expect(find.text('Técnico del equipo'), findsOneWidget);
    expect(consultas.single.queryParameters.containsKey('technicianId'), false);
  });

  testWidgets('el proveedor filtra por técnico con technicianId', (
    tester,
  ) async {
    await abrir(tester, rol: RolUsuario.proveedor);

    await elegirTecnico(tester, 'Luis Mora');
    expect(consultas.last.queryParameters['technicianId'], 't-2');

    // El filtro de estado conserva el técnico elegido.
    await tester.tap(clave('filtro-pendientes'));
    await tester.pumpAndSettle();
    expect(consultas.last.queryParameters, {
      'technicianId': 't-2',
      'status': 'pendiente',
      'page': 1,
      'size': 20,
    });

    final antes = consultas.length;
    await elegirTecnico(tester, 'Luis Mora');
    expect(consultas.length, antes);

    await elegirTecnico(tester, 'Todo el equipo');
    expect(consultas.last.queryParameters.containsKey('technicianId'), isFalse);
  });

  testWidgets('sin la lista del equipo, el proveedor ve los pagos igual', (
    tester,
  ) async {
    responderEquipo = (o) => respuestaJson(<String, dynamic>{}, 503);
    await abrir(tester, rol: RolUsuario.proveedor);

    expect(clave('selector-tecnico'), findsNothing);
    expect(find.text(r'$ 125.000'), findsOneWidget);
    expect(find.text('Técnico del equipo'), findsOneWidget);
  });

  testWidgets('«Cargar más» trae la página siguiente', (tester) async {
    responder = (o) => o.queryParameters['page'] == 1
        ? respuestaJson(_pagina([_pago('p-1')], total: 2), 200)
        : respuestaJson(
            _pagina([_pago('p-2', amount: '90000.00')], page: 2, total: 2),
            200,
          );
    await abrir(tester);

    await tester.tap(clave('boton-cargar-mas'));
    await tester.pumpAndSettle();
    expect(consultas.last.queryParameters['page'], 2);
    expect(find.text(r'$ 125.000'), findsOneWidget);
    expect(find.text(r'$ 90.000'), findsOneWidget);
    expect(clave('boton-cargar-mas'), findsNothing);
  });

  testWidgets('si «Cargar más» falla, conserva la lista', (tester) async {
    responder = (o) => o.queryParameters['page'] == 1
        ? respuestaJson(_pagina([_pago('p-1')], total: 2), 200)
        : respuestaJson(<String, dynamic>{}, 503);
    await abrir(tester);

    await tester.tap(clave('boton-cargar-mas'));
    await tester.pumpAndSettle();
    expect(find.text(r'$ 125.000'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('sin pagos lo dice según el filtro', (tester) async {
    responder = (o) => respuestaJson(_pagina(const []), 200);
    await abrir(tester);
    expect(find.text('Aún no hay pagos.'), findsOneWidget);
    expect(
      find.text('Cuando se complete un servicio, su pago aparecerá aquí.'),
      findsOneWidget,
    );

    await tester.tap(clave('filtro-pendientes'));
    await tester.pumpAndSettle();
    expect(find.text('No hay pagos pendientes.'), findsOneWidget);
  });

  testWidgets('un error permite reintentar', (tester) async {
    responder = (o) => respuestaJson(<String, dynamic>{}, 503);
    await abrir(tester);
    expect(clave('error-pagos'), findsOneWidget);

    responder = (o) => respuestaJson(_pagina([_pago('p-1')]), 200);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text(r'$ 125.000'), findsOneWidget);
  });

  testWidgets('deslizar recarga la lista', (tester) async {
    await abrir(tester);
    responder = (o) =>
        respuestaJson(_pagina([_pago('p-3', amount: '70000.00')]), 200);

    await tester.fling(clave('lista-pagos'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.text(r'$ 70.000'), findsOneWidget);
  });

  testWidgets('si recargar falla, conserva la lista', (tester) async {
    await abrir(tester);
    responder = (o) => respuestaJson(<String, dynamic>{}, 503);

    await tester.fling(clave('lista-pagos'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.text(r'$ 125.000'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('la lista vacía también se recarga al deslizar', (tester) async {
    responder = (o) => respuestaJson(_pagina(const []), 200);
    await abrir(tester);
    responder = (o) => respuestaJson(_pagina([_pago('p-1')]), 200);

    await tester.fling(clave('pagos-vacio'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.text(r'$ 125.000'), findsOneWidget);
  });

  testWidgets('el técnico también llega desde Inicio', (tester) async {
    await abrirCuenta(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('barra-navegacion')),
        matching: find.text('Inicio'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Pagos recibidos'), 200);
    await tester.tap(find.text('Pagos recibidos'));
    await tester.pumpAndSettle();
    expect(find.byType(MisPagosPage), findsOneWidget);
  });

  testWidgets('tema oscuro y texto al 200 % sin desbordes', (tester) async {
    await abrir(
      tester,
      rol: RolUsuario.proveedor,
      tema: AppTheme.oscuro(),
      escalaTexto: 2,
    );
    expect(tester.takeException(), isNull);
    expect(clave('selector-tecnico'), findsOneWidget);
    expect(clave('filtro-recibidos'), findsOneWidget);
  });

  test('lee el pago recibido del contrato', () {
    final pago = PagoRecibido.desdeJson(_pago('p-1', status: 'pendiente'));
    expect(pago.solicitudId, 'sr-p-1');
    expect(pago.tecnicoId, 't-1');
    expect(pago.estado, EstadoPago.pendiente);
    expect(pago.aprobadoEn, isNull);
    expect(pago.creadoEn, DateTime.utc(2026, 10, 20, 14, 10));

    final aprobado = PagoRecibido.desdeJson(_pago('p-2'));
    expect(aprobado.aprobadoEn, DateTime.utc(2026, 10, 20, 14, 30));
  });

  test('el equipo completo se pide página por página', () async {
    final pedidas = <int>[];
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(clienteApiProvider).httpClientAdapter = AdaptadorFalso((o) {
      final pagina = o.queryParameters['page'] as int;
      pedidas.add(pagina);
      return respuestaJson(
        _pagina(
          [_tecnico('t-$pagina', 'Técnico $pagina')],
          page: pagina,
          total: 3,
        ),
        200,
      );
    });

    final equipo = await container.read(equipoCompletoProvider.future);
    expect(equipo.map((t) => t.userId), ['t-1', 't-2', 't-3']);
    expect(pedidas, [1, 2, 3]);
  });
}
