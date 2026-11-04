import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quickpatch_mobile/app/app.dart';
import 'package:quickpatch_mobile/app/shell/inicio_page.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/core/catalogo/categoria.dart';
import 'package:quickpatch_mobile/core/catalogo/repositorio_catalogo.dart';
import 'package:quickpatch_mobile/core/geo/mapa_localidades.dart';
import 'package:quickpatch_mobile/core/geo/repositorio_localidades.dart';
import 'package:quickpatch_mobile/core/network/cliente_api.dart';
import 'package:quickpatch_mobile/core/realtime/canal_tiempo_real.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';
import 'package:quickpatch_mobile/features/notificaciones/presentation/paginas/notificaciones_page.dart';
import 'package:quickpatch_mobile/features/solicitudes/data/repositorio_solicitudes.dart';
import 'package:quickpatch_mobile/features/solicitudes/domain/modelos.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/paginas/detalle_solicitud_page.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/paginas/servicios_tecnico_page.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/paginas/solicitud_asignada_page.dart';

import '../../helpers/fakes.dart';

/// SCRUM-459: buzón de notificaciones (communication.v1.yaml 1.2.0).
final _mapa = MapaLocalidades.desdeGeoJson(
  File(rutaMapaLocalidades).readAsStringSync(),
);

Map<String, dynamic> _notificacion(
  String id, {
  String tipo = 'tecnico-asignado',
  String? solicitud = 's-1',
  bool leida = false,
}) => {
  'id': id,
  'type': tipo,
  'title': 'Título $id',
  'message': 'Mensaje de $id',
  'serviceRequestId': solicitud,
  'createdAt': '2026-10-17T15:00:00Z',
  'readAt': leida ? '2026-10-17T15:05:00Z' : null,
};

Map<String, dynamic> _pagina(
  List<Map<String, dynamic>> items, {
  int page = 1,
  int? total,
  int? sinLeer,
}) => {
  'items': items,
  'page': page,
  'size': 20,
  'totalItems': total ?? items.length,
  'unreadCount': sinLeer ?? items.where((n) => n['readAt'] == null).length,
};

void main() {
  late List<RequestOptions> peticiones;
  late ResponseBody Function(RequestOptions) buzon;
  late ResponseBody Function(RequestOptions) marcar;
  // Comprobación de que la solicitud sigue disponible antes de abrirla.
  late ResponseBody Function(RequestOptions) detalle;
  late ConectorWsFalso conector;

  setUp(() {
    peticiones = [];
    buzon = (o) => respuestaJson(
      _pagina([
        _notificacion('n-1'),
        _notificacion('n-2', tipo: 'solicitud-creada', leida: true),
      ]),
      200,
    );
    marcar = (o) => respuestaJson(_notificacion('n-1', leida: true), 200);
    detalle = (o) => respuestaJson(<String, dynamic>{'id': 's-1'}, 200);
    conector = ConectorWsFalso();
  });

  Future<void> abrir(
    WidgetTester tester, {
    RolUsuario rol = RolUsuario.cliente,
  }) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final memoria = AlmacenSeguroEnMemoria();
    await AlmacenSesion(memoria).guardar(sesionDePrueba(rol: rol));
    final container = ProviderContainer(
      overrides: [
        almacenSeguroProvider.overrideWithValue(memoria),
        conectorWsProvider.overrideWithValue(conector.call),
        categoriasProvider.overrideWith(
          (ref) async => const [Categoria(id: 'c-1', nombre: 'Plomería')],
        ),
        localidadesProvider.overrideWith((ref) async => const []),
        mapaLocalidadesProvider.overrideWith((ref) async => _mapa),
        solicitudProvider.overrideWith(
          (ref, id) async => Solicitud(
            id: id,
            estado: EstadoSolicitud.asignado,
            categoriaId: 'c-1',
            descripcion: 'Fuga de agua debajo del lavaplatos',
            ubicacion: const Ubicacion(4.6486, -74.0630),
            direccion: 'Carrera 7 # 63-44',
            creadaEn: DateTime.utc(2026, 10, 17, 15),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(clienteApiProvider).httpClientAdapter = AdaptadorFalso((o) {
      peticiones.add(o);
      if (o.path == '/v1/notifications') return buzon(o);
      if (o.path.startsWith('/v1/notifications/')) return marcar(o);
      if (RegExp(r'^/v1/service-requests/[^/]+$').hasMatch(o.path)) {
        return detalle(o);
      }
      // Sin servicios ni oferta pendiente en la pestaña Servicios.
      if (o.path == '/v1/technicians/me/service-requests' ||
          o.path == '/v1/matching/offers') {
        return respuestaJson(_pagina(const []), 200);
      }
      // Sin cotizaciones en el detalle (SCRUM-489).
      if (o.path.endsWith('/quotes')) return respuestaJson(<dynamic>[], 200);
      return respuestaJson(<String, dynamic>{}, 404);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QuickpatchApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder clave(String k) => find.byKey(Key(k));
  Iterable<RequestOptions> marcados() =>
      peticiones.where((o) => o.method == 'POST');

  Future<void> abrirBuzon(WidgetTester tester) async {
    await tester.tap(clave('campana-notificaciones'));
    await tester.pumpAndSettle();
  }

  group('campana del inicio', () {
    testWidgets('muestra cuántas sin leer y abre el buzón', (tester) async {
      await abrir(tester);
      final contador = peticiones.firstWhere(
        (o) => o.path == '/v1/notifications',
      );
      expect(contador.queryParameters, {'unread': true, 'size': 1});
      expect(find.byTooltip('Notificaciones, 1 sin leer'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      await abrirBuzon(tester);
      expect(find.byType(NotificacionesPage), findsOneWidget);
    });

    testWidgets('más de 9 sin leer se muestra como 9+', (tester) async {
      buzon = (o) => respuestaJson(_pagina(const [], sinLeer: 12), 200);
      await abrir(tester);
      expect(find.text('9+'), findsOneWidget);
      expect(find.byTooltip('Notificaciones, 12 sin leer'), findsOneWidget);
    });

    testWidgets('sin pendientes no muestra número', (tester) async {
      buzon = (o) => respuestaJson(_pagina(const []), 200);
      await abrir(tester);
      expect(find.byTooltip('Notificaciones'), findsOneWidget);
    });

    testWidgets('el contador se actualiza con cada aviso del canal', (
      tester,
    ) async {
      await abrir(tester);
      conector.ultima.recibir({'type': 'auth.accepted'});
      await tester.pumpAndSettle();
      buzon = (o) => respuestaJson(_pagina(const [], sinLeer: 3), 200);
      conector.ultima.recibir({
        'type': 'service-request.status-changed',
        'serviceRequestId': 's-1',
        'status': 'asignado',
      });
      await tester.pumpAndSettle();
      expect(find.byTooltip('Notificaciones, 3 sin leer'), findsOneWidget);
    });

    testWidgets('sin canal, el contador se consulta cada 30 s', (tester) async {
      conector.fallar = true;
      await abrir(tester);
      buzon = (o) => respuestaJson(_pagina(const [], sinLeer: 4), 200);
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Notificaciones, 4 sin leer'), findsOneWidget);
    });

    testWidgets('el proveedor no tiene buzón y no lo consulta', (tester) async {
      await abrir(tester, rol: RolUsuario.proveedor);
      expect(clave('campana-notificaciones'), findsNothing);
      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();
      expect(clave('fila-notificaciones'), findsNothing);
      expect(peticiones.where((o) => o.path == '/v1/notifications'), isEmpty);
    });
  });

  testWidgets('la fila de Cuenta muestra las sin leer y abre el buzón', (
    tester,
  ) async {
    buzon = (o) => respuestaJson(
      _pagina([_notificacion('n-1'), _notificacion('n-3')]),
      200,
    );
    await abrir(tester);
    await tester.tap(find.text('Cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('2 sin leer'), findsOneWidget);
    await tester.tap(clave('fila-notificaciones'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificacionesPage), findsOneWidget);
  });

  group('buzón', () {
    testWidgets('lista las notificaciones y marca las no leídas', (
      tester,
    ) async {
      await abrir(tester);
      await abrirBuzon(tester);

      expect(find.text('Título n-1'), findsOneWidget);
      expect(find.text('Mensaje de n-1'), findsOneWidget);
      expect(find.text('Título n-2'), findsOneWidget);
      // Solo la no leída lleva el punto, y el lector lo dice en palabras.
      expect(clave('punto-no-leida'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('No leída')), findsOneWidget);
    });

    testWidgets('tocar una del cliente la marca leída y abre la solicitud', (
      tester,
    ) async {
      await abrir(tester);
      await abrirBuzon(tester);
      buzon = (o) => respuestaJson(
        _pagina([
          _notificacion('n-1', leida: true),
          _notificacion('n-2', tipo: 'solicitud-creada', leida: true),
        ]),
        200,
      );

      await tester.tap(find.text('Título n-1'));
      await tester.pumpAndSettle();
      expect(marcados().single.path, '/v1/notifications/n-1/read');
      expect(find.byType(DetalleSolicitudPage), findsOneWidget);
      GoRouter.of(tester.element(find.byType(DetalleSolicitudPage))).pop();
      await tester.pumpAndSettle();
      expect(clave('punto-no-leida'), findsNothing);

      // Al volver al inicio, la campana ya no cuenta la que se leyó.
      GoRouter.of(tester.element(find.byType(NotificacionesPage))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(InicioPage), findsOneWidget);
      expect(find.byTooltip('Notificaciones'), findsOneWidget);
    });

    testWidgets('una ya leída no se vuelve a marcar', (tester) async {
      await abrir(tester);
      await abrirBuzon(tester);
      await tester.tap(find.text('Título n-2'));
      await tester.pumpAndSettle();
      expect(marcados(), isEmpty);
      expect(find.byType(DetalleSolicitudPage), findsOneWidget);
    });

    testWidgets('si marcar falla, igual abre su pantalla', (tester) async {
      marcar = (o) => respuestaJson(<String, dynamic>{}, 503);
      await abrir(tester);
      await abrirBuzon(tester);
      await tester.tap(find.text('Título n-1'));
      await tester.pumpAndSettle();
      expect(find.byType(DetalleSolicitudPage), findsOneWidget);
    });

    testWidgets('cada tipo de 1.2.0 tiene su icono', (tester) async {
      buzon = (o) => respuestaJson(
        _pagina([
          _notificacion('n-1', tipo: 'solicitud-cancelada'),
          _notificacion('n-2', tipo: 'cotizacion-recibida'),
          _notificacion('n-3', tipo: 'cotizacion-aceptada'),
          _notificacion('n-4', tipo: 'cotizacion-rechazada'),
          _notificacion('n-5', tipo: 'pago-aprobado'),
        ]),
        200,
      );
      await abrir(tester);
      await abrirBuzon(tester);

      Finder iconoDe(String id) => find.descendant(
        of: clave('notificacion-$id'),
        matching: find.byType(Icon),
      );
      IconData? icono(String id) => tester.widget<Icon>(iconoDe(id).first).icon;
      expect(icono('n-1'), Icons.cancel_outlined);
      for (final id in ['n-2', 'n-3', 'n-4']) {
        expect(icono(id), Icons.request_quote_outlined);
      }
      // Un tipo que la app no conoce usa el icono genérico.
      expect(icono('n-5'), Icons.notifications_none_rounded);
    });

    testWidgets('un tipo que la app no conoce se muestra y no navega', (
      tester,
    ) async {
      buzon = (o) => respuestaJson(
        _pagina([_notificacion('n-9', tipo: 'pago-aprobado', solicitud: null)]),
        200,
      );
      await abrir(tester);
      await abrirBuzon(tester);
      expect(find.text('Título n-9'), findsOneWidget);
      await tester.tap(find.text('Título n-9'));
      await tester.pumpAndSettle();
      expect(marcados().single.path, '/v1/notifications/n-9/read');
      expect(find.byType(NotificacionesPage), findsOneWidget);
    });

    testWidgets('«Cargar más» trae la página siguiente', (tester) async {
      buzon = (o) => o.queryParameters['unread'] == true
          ? respuestaJson(_pagina(const [], sinLeer: 2), 200)
          : o.queryParameters['page'] == 1
          ? respuestaJson(_pagina([_notificacion('n-1')], total: 2), 200)
          : respuestaJson(
              _pagina([_notificacion('n-2')], page: 2, total: 2),
              200,
            );
      await abrir(tester);
      await abrirBuzon(tester);
      expect(find.text('Título n-2'), findsNothing);
      await tester.tap(clave('boton-cargar-mas'));
      await tester.pumpAndSettle();
      expect(find.text('Título n-2'), findsOneWidget);
      expect(clave('boton-cargar-mas'), findsNothing);
    });

    testWidgets('sin notificaciones lo dice', (tester) async {
      buzon = (o) => respuestaJson(_pagina(const []), 200);
      await abrir(tester);
      await abrirBuzon(tester);
      expect(clave('notificaciones-vacio'), findsOneWidget);
    });

    testWidgets('un error permite reintentar', (tester) async {
      await abrir(tester);
      buzon = (o) => respuestaJson(<String, dynamic>{}, 404);
      await abrirBuzon(tester);
      expect(clave('error-notificaciones'), findsOneWidget);

      buzon = (o) => respuestaJson(_pagina([_notificacion('n-1')]), 200);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Título n-1'), findsOneWidget);
    });

    testWidgets('se recarga con cada aviso del canal', (tester) async {
      await abrir(tester);
      await abrirBuzon(tester);
      conector.ultima.recibir({'type': 'auth.accepted'});
      await tester.pumpAndSettle();
      buzon = (o) => respuestaJson(
        _pagina([_notificacion('n-5'), _notificacion('n-1')]),
        200,
      );
      conector.ultima.recibir({
        'type': 'service-request.status-changed',
        'serviceRequestId': 's-5',
        'status': 'asignado',
      });
      await tester.pumpAndSettle();
      expect(find.text('Título n-5'), findsOneWidget);
    });

    testWidgets('tema oscuro y texto al 200 % sin desbordes', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await abrir(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await abrirBuzon(tester);
      expect(tester.takeException(), isNull);
      final contexto = tester.element(find.byType(NotificacionesPage));
      expect(Theme.of(contexto).colorScheme, AppTheme.esquemaOscuro);
    });
  });

  group('destinos del técnico', () {
    testWidgets('solicitud-asignada abre el servicio asignado', (tester) async {
      buzon = (o) => respuestaJson(
        _pagina([_notificacion('n-1', tipo: 'solicitud-asignada')]),
        200,
      );
      await abrir(tester, rol: RolUsuario.tecnico);
      await abrirBuzon(tester);
      await tester.tap(find.text('Título n-1'));
      await tester.pumpAndSettle();
      expect(find.byType(SolicitudAsignadaPage), findsOneWidget);
    });

    testWidgets('oferta-recibida lleva a la pestaña Servicios', (tester) async {
      buzon = (o) => respuestaJson(
        _pagina([_notificacion('n-1', tipo: 'oferta-recibida')]),
        200,
      );
      await abrir(tester, rol: RolUsuario.tecnico);
      await abrirBuzon(tester);
      await tester.tap(find.text('Título n-1'));
      await tester.pumpAndSettle();
      expect(find.byType(ServiciosTecnicoPage), findsOneWidget);
    });

    testWidgets('verificacion-actualizada lleva al inicio', (tester) async {
      buzon = (o) => respuestaJson(
        _pagina([
          _notificacion(
            'n-1',
            tipo: 'verificacion-actualizada',
            solicitud: null,
          ),
        ]),
        200,
      );
      await abrir(tester, rol: RolUsuario.tecnico);
      await abrirBuzon(tester);
      await tester.tap(find.text('Título n-1'));
      await tester.pumpAndSettle();
      expect(find.byType(InicioPage), findsOneWidget);
      expect(find.byType(NotificacionesPage), findsNothing);
    });
  });

  group('tipos de 1.2.0 y solicitudes que ya no están disponibles', () {
    Future<void> tocar(
      WidgetTester tester,
      String tipo, {
      RolUsuario rol = RolUsuario.cliente,
    }) async {
      buzon = (o) =>
          respuestaJson(_pagina([_notificacion('n-1', tipo: tipo)]), 200);
      await abrir(tester, rol: rol);
      await abrirBuzon(tester);
      await tester.tap(find.text('Título n-1'));
      await tester.pumpAndSettle();
    }

    Iterable<RequestOptions> consultasDetalle() =>
        peticiones.where((o) => o.path == '/v1/service-requests/s-1');

    testWidgets('solicitud-cancelada abre el detalle del cliente', (
      tester,
    ) async {
      await tocar(tester, 'solicitud-cancelada');
      expect(find.byType(DetalleSolicitudPage), findsOneWidget);
    });

    testWidgets('solicitud-cancelada no navega para el técnico', (
      tester,
    ) async {
      await tocar(tester, 'solicitud-cancelada', rol: RolUsuario.tecnico);
      expect(marcados().single.path, '/v1/notifications/n-1/read');
      expect(find.byType(NotificacionesPage), findsOneWidget);
      // Sin destino no consulta el detalle (RN-SR13).
      expect(consultasDetalle(), isEmpty);
    });

    testWidgets('cotizacion-recibida abre el detalle del cliente', (
      tester,
    ) async {
      await tocar(tester, 'cotizacion-recibida');
      expect(find.byType(DetalleSolicitudPage), findsOneWidget);
    });

    for (final tipo in ['cotizacion-aceptada', 'cotizacion-rechazada']) {
      testWidgets('$tipo abre el servicio asignado del técnico', (
        tester,
      ) async {
        await tocar(tester, tipo, rol: RolUsuario.tecnico);
        expect(consultasDetalle(), hasLength(1));
        expect(find.byType(SolicitudAsignadaPage), findsOneWidget);
      });
    }

    for (final status in [403, 404]) {
      testWidgets('con $status la marca leída y avisa sin abrir el detalle', (
        tester,
      ) async {
        detalle = (o) => respuestaJson(<String, dynamic>{}, status);
        await tocar(tester, 'cotizacion-rechazada', rol: RolUsuario.tecnico);
        expect(marcados().single.path, '/v1/notifications/n-1/read');
        expect(
          find.text('Esta solicitud ya no está disponible.'),
          findsOneWidget,
        );
        expect(find.byType(NotificacionesPage), findsOneWidget);
        expect(find.byType(SolicitudAsignadaPage), findsNothing);
        expect(clave('punto-no-leida'), findsNothing);
      });
    }

    testWidgets('con otro error abre el detalle, que lo muestra', (
      tester,
    ) async {
      detalle = (o) => respuestaJson(<String, dynamic>{}, 500);
      await tocar(tester, 'tecnico-asignado');
      expect(find.byType(DetalleSolicitudPage), findsOneWidget);
    });
  });
}
