import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/app.dart';
import 'package:quickpatch_mobile/app/router/app_router.dart';
import 'package:quickpatch_mobile/app/router/rutas.dart';
import 'package:quickpatch_mobile/core/network/cliente_api.dart';
import 'package:quickpatch_mobile/core/realtime/canal_tiempo_real.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';
import 'package:quickpatch_mobile/features/solicitudes/domain/modelos.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/paginas/detalle_solicitud_page.dart';

import '../../helpers/fakes.dart';

/// Lista de solicitudes del cliente y de la empresa (RF-11, RF-08; SCRUM-74,
/// service-request 1.9.0). La sesión de prueba es la del usuario `u-1`.
Map<String, dynamic> _item(
  String id, {
  String cliente = 'u-1',
  String estado = 'asignado',
  String tipo = 'hogar',
  String? sede,
}) => {
  'id': id,
  'status': estado,
  'categoryId': 'c-1',
  'clientId': cliente,
  'technicianId': null,
  'createdAt': '2026-10-21T15:00:00Z',
  'assignedAt': null,
  'description': 'Descripción de $id',
  'clientType': tipo,
  'companyId': tipo == 'empresa' ? 'e-1' : null,
  'siteName': sede,
};

Map<String, dynamic> _detalle(String id, {String tipo = 'empresa'}) => {
  'id': id,
  'status': 'cotizado',
  'categoryId': 'c-1',
  'technicianId': 't-1',
  'description': 'Descripción de $id',
  'location': {'latitude': 4.65, 'longitude': -74.06},
  'addressText': 'Carrera 7 # 71-21',
  'createdAt': '2026-10-21T15:00:00Z',
  'clientType': tipo,
  'companyId': tipo == 'empresa' ? 'e-1' : null,
  'siteName': tipo == 'empresa' ? 'Sede Norte' : null,
};

void main() {
  late List<RequestOptions> peticiones;
  late ResponseBody Function(RequestOptions) listar;
  late ProviderContainer container;

  setUp(() {
    peticiones = [];
    listar = (o) => respuestaJson({
      'items': [
        _item('s-1', tipo: 'empresa', sede: 'Sede Norte'),
        _item('s-2', cliente: 'u-9', tipo: 'empresa'),
      ],
      'page': 1,
      'size': 20,
      'totalItems': 2,
    }, 200);
  });

  Finder clave(String k) => find.byKey(Key(k));

  Future<void> abrir(
    WidgetTester tester, {
    RolUsuario rol = RolUsuario.empresaContacto,
  }) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final memoria = AlmacenSeguroEnMemoria();
    await AlmacenSesion(memoria).guardar(sesionDePrueba(rol: rol));
    container = ProviderContainer(
      overrides: [
        almacenSeguroProvider.overrideWithValue(memoria),
        conectorWsProvider.overrideWithValue(ConectorWsFalso().call),
      ],
    );
    addTearDown(container.dispose);
    container.read(clienteApiProvider).httpClientAdapter = AdaptadorFalso((o) {
      peticiones.add(o);
      if (o.path == '/v1/service-requests') return listar(o);
      if (o.path.startsWith('/v1/service-requests/s-')) {
        if (o.path.endsWith('/quotes')) return respuestaJson(<dynamic>[], 200);
        return respuestaJson(_detalle(o.path.split('/').last), 200);
      }
      if (o.path.endsWith('/categories')) {
        return respuestaJson([
          {'id': 'c-1', 'name': 'Aire acondicionado'},
        ], 200);
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
    container.read(routerProvider).go(Rutas.actividad);
    await tester.pumpAndSettle();
  }

  testWidgets('la empresa ve sus solicitudes con la sede y quién las creó', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.text('Solicitudes de la empresa'), findsWidgets);
    expect(find.text('2 solicitudes'), findsOneWidget);
    expect(find.text('Sede Norte'), findsOneWidget);
    expect(find.text('Creada por otro usuario de la empresa'), findsOneWidget);
    expect(find.text('Aire acondicionado'), findsNWidgets(2));
    final pedido = peticiones.firstWhere(
      (p) => p.path == '/v1/service-requests',
    );
    expect(pedido.queryParameters, {'page': 1, 'size': 20});
  });

  testWidgets('la de otro usuario se abre en solo lectura, sin acciones', (
    tester,
  ) async {
    await abrir(tester);

    await tester.tap(clave('solicitud-s-2'));
    await tester.pumpAndSettle();

    final pagina = tester.widget<DetalleSolicitudPage>(
      find.byType(DetalleSolicitudPage),
    );
    expect(pagina.soloLectura, isTrue);
    expect(clave('aviso-solo-lectura'), findsOneWidget);
    expect(clave('boton-cancelar-solicitud'), findsNothing);
    expect(clave('boton-chat'), findsNothing);
    expect(find.text('Sede Norte'), findsOneWidget);
  });

  testWidgets('la propia se abre con sus acciones', (tester) async {
    await abrir(tester);

    await tester.tap(clave('solicitud-s-1'));
    await tester.pumpAndSettle();

    final pagina = tester.widget<DetalleSolicitudPage>(
      find.byType(DetalleSolicitudPage),
    );
    expect(pagina.soloLectura, isFalse);
    expect(clave('aviso-solo-lectura'), findsNothing);
    expect(clave('boton-chat'), findsOneWidget);
    await tester.ensureVisible(clave('boton-cancelar-solicitud'));
    expect(clave('boton-cancelar-solicitud'), findsOneWidget);
  });

  testWidgets('el filtro pide un solo estado', (tester) async {
    await abrir(tester, rol: RolUsuario.cliente);

    await tester.tap(clave('filtro-completadas'));
    await tester.pumpAndSettle();

    expect(peticiones.last.queryParameters['status'], 'completado');
    expect(find.text('Solicitudes'), findsWidgets);
  });

  testWidgets('sin solicitudes ofrece crear una; con error, reintentar', (
    tester,
  ) async {
    listar = (_) =>
        respuestaJson({'type': 'x', 'title': 'x', 'status': 503}, 503);
    await abrir(tester, rol: RolUsuario.cliente);
    expect(clave('error-solicitudes'), findsOneWidget);

    listar = (_) => respuestaJson({
      'items': <dynamic>[],
      'page': 1,
      'size': 20,
      'totalItems': 0,
    }, 200);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(clave('solicitudes-vacio'), findsOneWidget);
    expect(clave('boton-nueva-solicitud'), findsOneWidget);
  });

  testWidgets('carga más solicitudes por páginas', (tester) async {
    var pagina = 0;
    listar = (_) {
      pagina++;
      return respuestaJson({
        'items': [_item('p$pagina')],
        'page': pagina,
        'size': 20,
        'totalItems': 2,
      }, 200);
    };
    await abrir(tester, rol: RolUsuario.cliente);

    await tester.tap(clave('boton-cargar-mas'));
    await tester.pumpAndSettle();

    expect(peticiones.last.queryParameters['page'], 2);
    expect(clave('solicitud-p2'), findsOneWidget);
    expect(clave('boton-cargar-mas'), findsNothing);
  });

  test(
    'el detalle lee el tipo de cliente y la sede; sin ellos es de hogar',
    () {
      final empresa = Solicitud.desdeJson(_detalle('s-1'));
      final antigua = Solicitud.desdeJson(
        _detalle('s-2', tipo: 'hogar')..remove('clientType'),
      );

      expect(empresa.tipoCliente, TipoCliente.empresa);
      expect(empresa.sede, 'Sede Norte');
      expect(antigua.tipoCliente, TipoCliente.hogar);
      expect(
        const NuevaSolicitud(
          categoriaId: 'c',
          descripcion: 'd',
          direccion: 'x',
          sede: '  ',
        ).toJson(),
        isNot(contains('siteName')),
      );
    },
  );
}
