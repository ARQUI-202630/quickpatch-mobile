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
import 'package:quickpatch_mobile/features/cuenta/presentation/paginas/cuenta_page.dart';
import 'package:quickpatch_mobile/features/solicitudes/data/repositorio_solicitudes.dart';
import 'package:quickpatch_mobile/features/solicitudes/domain/modelos.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/paginas/historial_tecnico_page.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/paginas/solicitud_asignada_page.dart';

import '../../helpers/fakes.dart';

/// SCRUM-101: historial del técnico desde Cuenta, con
/// `GET /v1/technicians/me/service-requests` (service-request 1.10.0).
const _ruta = '/v1/technicians/me/service-requests';

Map<String, dynamic> _servicio(
  String id, {
  String status = 'completado',
  int? score,
}) => {
  'id': id,
  'status': status,
  'categoryId': 'c-1',
  'description': 'Fuga de agua en $id',
  'createdAt': '2026-10-07T15:00:00Z',
  'assignedAt': '2026-10-07T15:20:00Z',
  'score': score,
  'ratedAt': score == null ? null : '2026-10-08T15:20:00Z',
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
    responder = (o) => respuestaJson(_pagina([_servicio('s-1')]), 200);
    conector = ConectorWsFalso();
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
      overrides: [
        cotizacionesProvider.overrideWith((ref, id) async => const []),
        almacenSeguroProvider.overrideWithValue(memoria),
        conectorWsProvider.overrideWithValue(conector.call),
        categoriasProvider.overrideWith(
          (ref) async => const [Categoria(id: 'c-1', nombre: 'Plomería')],
        ),
        localidadesProvider.overrideWith((ref) async => const []),
        solicitudProvider.overrideWith(
          (ref, id) async => Solicitud(
            id: id,
            estado: EstadoSolicitud.completado,
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
        matching: find.text('Cuenta'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder clave(String k) => find.byKey(Key(k));

  /// Abre el historial desde Cuenta, como técnico.
  Future<void> abrir(
    WidgetTester tester, {
    ThemeData? tema,
    double escalaTexto = 1,
  }) async {
    await abrirCuenta(tester, tema: tema, escalaTexto: escalaTexto);
    consultas.clear();
    await tester.tap(clave('fila-historial'));
    await tester.pumpAndSettle();
  }

  testWidgets('solo el técnico ve el historial en Cuenta', (tester) async {
    await abrirCuenta(tester, rol: RolUsuario.cliente);
    expect(find.byType(CuentaPage), findsOneWidget);
    expect(clave('fila-historial'), findsNothing);
  });

  testWidgets('empieza en Completados y vuelve con la flecha', (tester) async {
    await abrir(tester);

    expect(find.byType(HistorialTecnicoPage), findsOneWidget);
    expect(consultas.single.queryParameters, {
      'status': 'completado',
      'page': 1,
      'size': 20,
    });
    expect(find.text('1 servicio'), findsOneWidget);
    expect(find.text('Plomería'), findsOneWidget);
    expect(find.text('Sin calificar'), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(CuentaPage), findsOneWidget);
  });

  testWidgets('cada filtro consulta su estado', (tester) async {
    await abrir(tester);

    await tester.tap(clave('filtro-pagados'));
    await tester.pumpAndSettle();
    expect(consultas.last.queryParameters['status'], 'pagado');

    await tester.tap(clave('filtro-cancelados'));
    await tester.pumpAndSettle();
    expect(consultas.last.queryParameters['status'], 'cancelado');

    final antes = consultas.length;
    await tester.tap(clave('filtro-cancelados'));
    await tester.pumpAndSettle();
    expect(consultas.length, antes);
  });

  testWidgets('en Pagados muestra la calificación recibida', (tester) async {
    final semantica = tester.ensureSemantics();
    await abrir(tester);
    responder = (o) => respuestaJson(
      _pagina([
        _servicio('s-1', status: 'pagado', score: 4),
        _servicio('s-2', status: 'pagado'),
      ]),
      200,
    );

    await tester.tap(clave('filtro-pagados'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
    expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
    // La tarjeta une la semántica de su contenido en un solo nodo.
    expect(
      find.bySemanticsLabel(RegExp('Calificación: 4 de 5')),
      findsOneWidget,
    );
    expect(find.text('Sin calificar'), findsOneWidget);
    semantica.dispose();
  });

  testWidgets('solo los completados abren su detalle (RN-SR13)', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.text('Fuga de agua en s-1'));
    await tester.pumpAndSettle();
    expect(find.byType(SolicitudAsignadaPage), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    responder = (o) =>
        respuestaJson(_pagina([_servicio('s-2', status: 'pagado')]), 200);
    await tester.tap(clave('filtro-pagados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fuga de agua en s-2'));
    await tester.pumpAndSettle();
    expect(find.byType(SolicitudAsignadaPage), findsNothing);
  });

  testWidgets('«Cargar más» trae la página siguiente', (tester) async {
    responder = (o) => o.queryParameters['page'] == 1
        ? respuestaJson(_pagina([_servicio('s-1')], total: 2), 200)
        : respuestaJson(_pagina([_servicio('s-2')], page: 2, total: 2), 200);
    await abrir(tester);

    await tester.tap(clave('boton-cargar-mas'));
    await tester.pumpAndSettle();
    expect(consultas.last.queryParameters['page'], 2);
    expect(find.text('Fuga de agua en s-1'), findsOneWidget);
    expect(find.text('Fuga de agua en s-2'), findsOneWidget);
    expect(clave('boton-cargar-mas'), findsNothing);
  });

  testWidgets('si «Cargar más» falla, conserva la lista', (tester) async {
    responder = (o) => o.queryParameters['page'] == 1
        ? respuestaJson(_pagina([_servicio('s-1')], total: 2), 200)
        : respuestaJson(<String, dynamic>{}, 503);
    await abrir(tester);

    await tester.tap(clave('boton-cargar-mas'));
    await tester.pumpAndSettle();
    expect(find.text('Fuga de agua en s-1'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('sin servicios lo dice según el filtro', (tester) async {
    responder = (o) => respuestaJson(_pagina(const []), 200);
    await abrir(tester);
    expect(find.text('No tienes servicios completados.'), findsOneWidget);
    expect(
      find.text('Cuando termines un servicio, aparecerá aquí.'),
      findsOneWidget,
    );

    await tester.tap(clave('filtro-cancelados'));
    await tester.pumpAndSettle();
    expect(find.text('No tienes servicios cancelados.'), findsOneWidget);
  });

  testWidgets('un error permite reintentar', (tester) async {
    responder = (o) => respuestaJson(<String, dynamic>{}, 503);
    await abrir(tester);
    expect(clave('error-historial'), findsOneWidget);

    responder = (o) => respuestaJson(_pagina([_servicio('s-1')]), 200);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Fuga de agua en s-1'), findsOneWidget);
  });

  testWidgets('deslizar recarga la lista', (tester) async {
    await abrir(tester);
    responder = (o) => respuestaJson(_pagina([_servicio('s-3')]), 200);

    await tester.fling(clave('lista-historial'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Fuga de agua en s-3'), findsOneWidget);
  });

  testWidgets('el aviso de cambio de estado recarga la lista', (tester) async {
    await abrir(tester);
    conector.ultima.recibir({'type': 'auth.accepted'});
    await tester.pumpAndSettle();
    responder = (o) => respuestaJson(_pagina([_servicio('s-3')]), 200);

    conector.ultima.recibir({
      'type': 'service-request.status-changed',
      'serviceRequestId': 's-3',
      'status': 'completado',
    });
    await tester.pumpAndSettle();
    expect(find.text('Fuga de agua en s-3'), findsOneWidget);
  });

  testWidgets('si recargar falla, conserva la lista', (tester) async {
    await abrir(tester);
    responder = (o) => respuestaJson(<String, dynamic>{}, 503);

    await tester.fling(clave('lista-historial'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Fuga de agua en s-1'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('tema oscuro y texto al 200 % sin desbordes', (tester) async {
    await abrir(tester, tema: AppTheme.oscuro(), escalaTexto: 2);
    expect(tester.takeException(), isNull);
    expect(clave('filtro-cancelados'), findsOneWidget);
  });

  test('la lista lee la calificación; sin ella queda en null', () {
    final calificado = ServicioTecnico.desdeJson(
      _servicio('s-1', status: 'pagado', score: 5),
    );
    expect(calificado.puntaje, 5);
    expect(calificado.calificadaEn, DateTime.utc(2026, 10, 8, 15, 20));

    final json = _servicio('s-2')
      ..remove('score')
      ..remove('ratedAt');
    final sinCalificar = ServicioTecnico.desdeJson(json);
    expect(sinCalificar.puntaje, isNull);
    expect(sinCalificar.calificadaEn, isNull);
  });
}
