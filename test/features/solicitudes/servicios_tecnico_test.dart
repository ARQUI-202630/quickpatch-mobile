import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/app.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/core/catalogo/categoria.dart';
import 'package:quickpatch_mobile/core/catalogo/repositorio_catalogo.dart';
import 'package:quickpatch_mobile/core/geo/repositorio_localidades.dart';
import 'package:quickpatch_mobile/core/network/cliente_api.dart';
import 'package:quickpatch_mobile/core/realtime/canal_tiempo_real.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';
import 'package:quickpatch_mobile/features/solicitudes/data/repositorio_solicitudes.dart';
import 'package:quickpatch_mobile/features/solicitudes/domain/modelos.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/paginas/servicios_tecnico_page.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/paginas/solicitud_asignada_page.dart';

import '../../helpers/fakes.dart';

/// SCRUM-92: lista de servicios del técnico en la pestaña Servicios, con
/// `GET /v1/technicians/me/service-requests` (service-request 1.2.0).
const _ruta = '/v1/technicians/me/service-requests';

Map<String, dynamic> _servicio(
  String id, {
  String status = 'asignado',
  String categoria = 'c-1',
}) => {
  'id': id,
  'status': status,
  'categoryId': categoria,
  'description': 'Fuga de agua en $id',
  'createdAt': '2026-10-07T15:00:00Z',
  'assignedAt': '2026-10-07T15:20:00Z',
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

void main() {
  late List<RequestOptions> consultas;
  late ResponseBody Function(RequestOptions) responder;
  late ConectorWsFalso conector;

  setUp(() {
    consultas = [];
    responder = (o) => respuestaJson(
      _pagina([
        _servicio('s-1'),
        _servicio('s-2', status: 'completado', categoria: 'c-2'),
      ]),
      200,
    );
    conector = ConectorWsFalso();
  });

  /// Abre la app como técnico y va a la pestaña Servicios.
  Future<void> abrir(
    WidgetTester tester, {
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
    await AlmacenSesion(memoria)
        .guardar(sesionDePrueba(rol: RolUsuario.tecnico));
    final container = ProviderContainer(
      overrides: [
        // Sin cotizaciones (SCRUM-489); sus pruebas están en cotizacion_*_test.
        cotizacionesProvider.overrideWith((ref, id) async => const []),
        almacenSeguroProvider.overrideWithValue(memoria),
        conectorWsProvider.overrideWithValue(conector.call),
        categoriasProvider.overrideWith(
          (ref) async => const [
            Categoria(id: 'c-1', nombre: 'Plomería'),
            Categoria(id: 'c-2', nombre: 'Electricidad'),
          ],
        ),
        localidadesProvider.overrideWith((ref) async => const []),
        solicitudProvider.overrideWith(
          (ref, id) async => Solicitud(
            id: id,
            estado: EstadoSolicitud.asignado,
            categoriaId: 'c-1',
            descripcion: 'Fuga de agua en $id',
            ubicacion: const Ubicacion(4.6765, -74.0480),
            direccion: 'Calle 93 # 13-20',
            creadaEn: DateTime.utc(2026, 10, 7, 15),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(clienteApiProvider).httpClientAdapter = AdaptadorFalso((o) {
      // Sin oferta pendiente (la oferta se prueba en test/features/ofertas).
      if (o.path == '/v1/matching/offers') {
        return respuestaJson(_pagina(const []), 200);
      }
      if (o.path == _ruta) {
        consultas.add(o);
        return responder(o);
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
        matching: find.text('Servicios'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder clave(String k) => find.byKey(Key(k));

  testWidgets('lista los servicios asignados, sin dirección ni cliente', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.byType(ServiciosTecnicoPage), findsOneWidget);
    expect(consultas.single.queryParameters, {'page': 1, 'size': 20});
    expect(find.text('2 servicios'), findsOneWidget);
    expect(find.text('Plomería'), findsOneWidget);
    expect(find.text('Electricidad'), findsOneWidget);
    expect(find.text('Fuga de agua en s-1'), findsOneWidget);
    expect(find.text(EstadoSolicitud.asignado.etiqueta), findsOneWidget);
    expect(find.text(EstadoSolicitud.completado.etiqueta), findsOneWidget);
    // RN-SR13: la lista no trae dirección.
    expect(find.byIcon(Icons.place_outlined), findsNothing);
  });

  testWidgets('el filtro consulta un solo estado', (tester) async {
    await abrir(tester);

    responder = (o) => respuestaJson(_pagina([_servicio('s-1')]), 200);
    await tester.tap(clave('filtro-asignados'));
    await tester.pumpAndSettle();
    expect(consultas.last.queryParameters['status'], 'asignado');
    expect(find.text('1 servicio'), findsOneWidget);

    await tester.tap(clave('filtro-todos'));
    await tester.pumpAndSettle();
    expect(consultas.last.queryParameters.containsKey('status'), isFalse);
  });

  testWidgets('«Cargar más» trae la página siguiente', (tester) async {
    responder = (o) => o.queryParameters['page'] == 1
        ? respuestaJson(_pagina([_servicio('s-1')], total: 2), 200)
        : respuestaJson(_pagina([_servicio('s-2')], page: 2, total: 2), 200);
    await abrir(tester);

    expect(find.text('Fuga de agua en s-2'), findsNothing);
    await tester.tap(clave('boton-cargar-mas'));
    await tester.pumpAndSettle();
    expect(consultas.last.queryParameters['page'], 2);
    expect(find.text('Fuga de agua en s-1'), findsOneWidget);
    expect(find.text('Fuga de agua en s-2'), findsOneWidget);
    expect(clave('boton-cargar-mas'), findsNothing);
  });

  testWidgets('sin servicios lo dice, con y sin filtro', (tester) async {
    responder = (o) => respuestaJson(_pagina(const []), 200);
    await abrir(tester);
    expect(find.text('Aún no tienes servicios asignados.'), findsOneWidget);

    await tester.tap(clave('filtro-enProgreso'));
    await tester.pumpAndSettle();
    expect(find.text('No tienes servicios en progreso.'), findsOneWidget);
  });

  testWidgets('un error permite reintentar', (tester) async {
    responder = (o) => respuestaJson(<String, dynamic>{}, 503);
    await abrir(tester);
    expect(clave('error-servicios'), findsOneWidget);

    responder = (o) => respuestaJson(_pagina([_servicio('s-1')]), 200);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Fuga de agua en s-1'), findsOneWidget);
  });

  testWidgets('tocar un servicio abre su detalle', (tester) async {
    await abrir(tester);

    await tester.tap(find.text('Fuga de agua en s-1'));
    await tester.pumpAndSettle();
    expect(find.byType(SolicitudAsignadaPage), findsOneWidget);
    expect(find.text('Calle 93 # 13-20'), findsOneWidget);
  });

  group('aviso en tiempo real', () {
    /// Abre la lista, acepta el canal y envía el aviso de [id] con [status].
    Future<int> avisar(
      WidgetTester tester,
      String id, {
      String status = 'asignado',
    }) async {
      conector.ultima.recibir({'type': 'auth.accepted'});
      await tester.pumpAndSettle();
      final antes = consultas.length;
      conector.ultima.recibir({
        'type': 'service-request.status-changed',
        'serviceRequestId': id,
        'status': status,
      });
      await tester.pumpAndSettle();
      return antes;
    }

    testWidgets('recarga la lista una vez y muestra el servicio', (
      tester,
    ) async {
      await abrir(tester);
      responder = (o) =>
          respuestaJson(_pagina([_servicio('s-3'), _servicio('s-1')]), 200);
      final antes = await avisar(tester, 's-3');
      expect(consultas.length, antes + 1);
      expect(find.text('Fuga de agua en s-3'), findsOneWidget);
    });

    testWidgets('sin el servicio en la respuesta no vuelve a recargar', (
      tester,
    ) async {
      await abrir(tester);
      final antes = await avisar(tester, 's-3');
      expect(find.text('Fuga de agua en s-3'), findsNothing);

      // El aviso sale de ServiceRequest después de guardar (SCRUM-466): ya
      // no hay recarga de respaldo a los 2 s.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(consultas.length, antes + 1);
    });
  });

  testWidgets('tema oscuro y texto al 200 % sin desbordes', (tester) async {
    await abrir(tester, tema: AppTheme.oscuro(), escalaTexto: 2);
    expect(tester.takeException(), isNull);
    expect(clave('filtro-completados'), findsOneWidget);
  });
}
