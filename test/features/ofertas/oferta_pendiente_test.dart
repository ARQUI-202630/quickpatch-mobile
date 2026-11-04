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
import 'package:quickpatch_mobile/core/network/politica_reintento.dart';
import 'package:quickpatch_mobile/core/realtime/canal_tiempo_real.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';
import 'package:quickpatch_mobile/core/utils/reloj.dart';
import 'package:quickpatch_mobile/features/disponibilidad/presentation/paginas/disponibilidad_page.dart';
import 'package:quickpatch_mobile/features/ofertas/presentation/widgets/oferta_pendiente.dart';
import 'package:quickpatch_mobile/features/solicitudes/data/repositorio_solicitudes.dart';
import 'package:quickpatch_mobile/features/solicitudes/domain/modelos.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/paginas/solicitud_asignada_page.dart';

import '../../helpers/fakes.dart';

/// SCRUM-80: oferta pendiente del técnico arriba de su pestaña Servicios
/// (matching.v1.yaml 1.0.0).
final _inicio = DateTime.utc(2026, 10, 16, 15);

Map<String, dynamic> _oferta({
  String attemptId = 'a-1',
  String? categoria = 'Plomería',
  double distancia = 1234,
}) => {
  'attemptId': attemptId,
  'serviceRequestId': 's-1',
  'categoryId': 'c-1',
  'categoryName': categoria,
  'description': 'Fuga de agua debajo del lavaplatos',
  'locality': {'code': '02', 'name': 'Chapinero'},
  'distanceMeters': distancia,
  'offeredAt': _inicio.toIso8601String(),
  'expiresAt': _inicio.add(const Duration(minutes: 3)).toIso8601String(),
};

Map<String, dynamic> _pagina(List<Map<String, dynamic>> items) => {
  'items': items,
  'page': 1,
  'size': 20,
  'totalItems': items.length,
};

ResponseBody _problema(String tipo, int status) => respuestaJson({
  'type': 'https://quickpatch.co/problems/$tipo',
  'status': status,
}, status);

void main() {
  late List<RequestOptions> peticiones;
  late ResponseBody Function(RequestOptions) ofertas;
  late ResponseBody Function(RequestOptions) responder;
  late ConectorWsFalso conector;
  late DateTime ahora;

  setUp(() {
    peticiones = [];
    ofertas = (o) => respuestaJson(_pagina([_oferta()]), 200);
    responder = (o) =>
        respuestaJson({'attemptId': 'a-1', 'response': 'aceptado'}, 200);
    conector = ConectorWsFalso();
    ahora = _inicio.add(const Duration(seconds: 19));
  });

  /// Abre la app como técnico en la pestaña Servicios.
  Future<void> abrir(WidgetTester tester, {double escalaTexto = 1}) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = escalaTexto;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final memoria = AlmacenSeguroEnMemoria();
    await AlmacenSesion(memoria)
        .guardar(sesionDePrueba(rol: RolUsuario.tecnico));
    final container = ProviderContainer(
      // La misma política de reintentos de main.dart.
      retry: politicaReintento,
      overrides: [
        // Sin cotizaciones (SCRUM-489); sus pruebas están en cotizacion_*_test.
        cotizacionesProvider.overrideWith((ref, id) async => const []),
        almacenSeguroProvider.overrideWithValue(memoria),
        conectorWsProvider.overrideWithValue(conector.call),
        relojProvider.overrideWithValue(() => ahora),
        categoriasProvider.overrideWith(
          (ref) async => const [Categoria(id: 'c-1', nombre: 'Plomería')],
        ),
        localidadesProvider.overrideWith((ref) async => const []),
        solicitudProvider.overrideWith(
          (ref, id) async => Solicitud(
            id: id,
            estado: EstadoSolicitud.asignado,
            categoriaId: 'c-1',
            descripcion: 'Fuga de agua debajo del lavaplatos',
            ubicacion: const Ubicacion(4.6486, -74.0630),
            direccion: 'Carrera 7 # 63-44',
            creadaEn: _inicio,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(clienteApiProvider).httpClientAdapter = AdaptadorFalso((o) {
      peticiones.add(o);
      if (o.path == '/v1/matching/offers') return ofertas(o);
      if (o.path.startsWith('/v1/matching/offers/')) return responder(o);
      // La lista de servicios y la disponibilidad quedan vacías.
      return respuestaJson(_pagina(const []), 200);
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
  int consultasDeOfertas() =>
      peticiones.where((o) => o.path == '/v1/matching/offers').length;
  String texto(WidgetTester tester, String k) =>
      tester.widget<Text>(clave(k)).data!;

  testWidgets('muestra la oferta sin dirección y con su cuenta regresiva', (
    tester,
  ) async {
    await abrir(tester);

    expect(
      peticiones
          .firstWhere((o) => o.path == '/v1/matching/offers')
          .queryParameters['status'],
      'pendiente',
    );
    expect(find.text('Nueva oferta'), findsOneWidget);
    expect(texto(tester, 'oferta-servicio'), 'Plomería');
    expect(
      texto(tester, 'oferta-descripcion'),
      'Fuga de agua debajo del lavaplatos',
    );
    expect(texto(tester, 'oferta-lugar'), 'Chapinero · a 1,2 km');
    expect(texto(tester, 'oferta-tiempo'), 'Vence en 2:41');
    // RN-SR13: ni dirección ni cliente.
    expect(find.textContaining('Carrera'), findsNothing);

    ahora = ahora.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(texto(tester, 'oferta-tiempo'), 'Vence en 2:40');
  });

  testWidgets('sin el nombre de la réplica usa el catálogo', (tester) async {
    ofertas = (o) =>
        respuestaJson(_pagina([_oferta(categoria: null, distancia: 850)]), 200);
    await abrir(tester);
    expect(texto(tester, 'oferta-servicio'), 'Plomería');
    expect(texto(tester, 'oferta-lugar'), 'Chapinero · a 850 m');
  });

  testWidgets('sin oferta no ocupa espacio', (tester) async {
    ofertas = (o) => respuestaJson(_pagina(const []), 200);
    await abrir(tester);
    expect(clave('tarjeta-oferta'), findsNothing);
    expect(find.text('Nueva oferta'), findsNothing);
  });

  testWidgets('aceptar avisa y «Ver» abre el detalle del servicio', (
    tester,
  ) async {
    await abrir(tester);
    ofertas = (o) => respuestaJson(_pagina(const []), 200);

    await tester.tap(clave('boton-aceptar-oferta'));
    await tester.pumpAndSettle();
    final aceptar = peticiones.lastWhere((o) => o.method == 'POST');
    expect(aceptar.method, 'POST');
    expect(aceptar.path, '/v1/matching/offers/a-1/accept');
    expect(find.text('Aceptaste el servicio.'), findsOneWidget);
    expect(clave('tarjeta-oferta'), findsNothing);

    await tester.tap(find.text('Ver'));
    await tester.pumpAndSettle();
    expect(find.byType(SolicitudAsignadaPage), findsOneWidget);
  });

  testWidgets('rechazar pide confirmación y no penaliza', (tester) async {
    await abrir(tester);

    await tester.tap(clave('boton-rechazar-oferta'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No tiene penalización'), findsOneWidget);
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(peticiones.where((o) => o.method == 'POST'), isEmpty);

    ofertas = (o) => respuestaJson(_pagina(const []), 200);
    await tester.tap(clave('boton-rechazar-oferta'));
    await tester.pumpAndSettle();
    await tester.tap(clave('confirmar-rechazo'));
    await tester.pumpAndSettle();
    expect(
      peticiones.lastWhere((o) => o.method == 'POST').path,
      '/v1/matching/offers/a-1/reject',
    );
    expect(find.text('Rechazaste la oferta.'), findsOneWidget);
    expect(clave('tarjeta-oferta'), findsNothing);
  });

  testWidgets('409 oferta-no-disponible la quita y lo explica', (tester) async {
    await abrir(tester);
    responder = (o) => _problema('oferta-no-disponible', 409);
    ofertas = (o) => respuestaJson(_pagina(const []), 200);

    await tester.tap(clave('boton-aceptar-oferta'));
    await tester.pumpAndSettle();
    expect(find.text('Esta oferta ya no está disponible.'), findsOneWidget);
    expect(clave('tarjeta-oferta'), findsNothing);
  });

  testWidgets('409 tecnico-no-disponible lleva a Disponibilidad', (
    tester,
  ) async {
    await abrir(tester);
    responder = (o) => _problema('tecnico-no-disponible', 409);
    ofertas = (o) => respuestaJson(_pagina(const []), 200);

    await tester.tap(clave('boton-aceptar-oferta'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ya no estás disponible para aceptar ofertas.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Disponibilidad'));
    await tester.pumpAndSettle();
    expect(find.byType(DisponibilidadPage), findsOneWidget);
  });

  testWidgets('otro error deja la oferta para volver a intentar', (
    tester,
  ) async {
    await abrir(tester);
    responder = (o) => respuestaJson(<String, dynamic>{}, 503);

    await tester.tap(clave('boton-aceptar-oferta'));
    await tester.pumpAndSettle();
    expect(clave('tarjeta-oferta'), findsOneWidget);
    final boton = tester.widget<FilledButton>(clave('boton-aceptar-oferta'));
    expect(boton.onPressed, isNotNull);
  });

  testWidgets('al vencer desactiva los botones y vuelve a consultar', (
    tester,
  ) async {
    await abrir(tester);
    final antes = consultasDeOfertas();
    ofertas = (o) => respuestaJson(_pagina(const []), 200);

    ahora = _inicio.add(const Duration(minutes: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(texto(tester, 'oferta-tiempo'), 'La oferta venció.');
    expect(
      tester.widget<FilledButton>(clave('boton-aceptar-oferta')).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(clave('boton-rechazar-oferta')).onPressed,
      isNull,
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(consultasDeOfertas(), antes + 1);
    expect(clave('tarjeta-oferta'), findsNothing);
  });

  testWidgets(
    'con el reloj adelantado sigue consultando hasta que desaparece',
    (tester) async {
      await abrir(tester);
      final antes = consultasDeOfertas();

      // El teléfono cree que venció, pero Matching (reloj del servidor) todavía
      // la devuelve dos consultas más.
      var pendientes = 2;
      ofertas = (o) => pendientes-- > 0
          ? respuestaJson(_pagina([_oferta()]), 200)
          : respuestaJson(_pagina(const []), 200);
      ahora = _inicio.add(const Duration(minutes: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(texto(tester, 'oferta-tiempo'), 'La oferta venció.');

      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(consultasDeOfertas(), antes + 3);
      expect(clave('tarjeta-oferta'), findsNothing);

      // Sin oferta no vuelve a consultar cada 3 s.
      await tester.pump(const Duration(seconds: 9));
      expect(consultasDeOfertas(), antes + 3);
    },
  );

  testWidgets('sin descripción lo dice en vez de dejar el espacio vacío', (
    tester,
  ) async {
    ofertas = (o) => respuestaJson(
      _pagina([
        {..._oferta(), 'description': '  '},
      ]),
      200,
    );
    await abrir(tester);
    expect(texto(tester, 'oferta-descripcion'), 'Sin descripción');
  });

  testWidgets('en Servicios, offer.created muestra la oferta sin avisar', (
    tester,
  ) async {
    ofertas = (o) => respuestaJson(_pagina(const []), 200);
    await abrir(tester);
    conector.ultima.recibir({'type': 'auth.accepted'});
    await tester.pumpAndSettle();

    ofertas = (o) => respuestaJson(_pagina([_oferta()]), 200);
    conector.ultima.recibir({
      'type': 'offer.created',
      'attemptId': 'a-1',
      'serviceRequestId': 's-1',
      'expiresAt': _inicio.add(const Duration(minutes: 3)).toIso8601String(),
      'occurredAt': _inicio.toIso8601String(),
    });
    await tester.pumpAndSettle();
    expect(clave('tarjeta-oferta'), findsOneWidget);
    // Ya está en Servicios: el aviso con «Ver» llevaría a la misma pantalla.
    expect(find.text('Tienes una oferta nueva.'), findsNothing);
  });

  testWidgets('desde otra pestaña, «Ver» lleva a Servicios', (tester) async {
    ofertas = (o) => respuestaJson(_pagina(const []), 200);
    await abrir(tester);
    conector.ultima.recibir({'type': 'auth.accepted'});
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('barra-navegacion')),
        matching: find.text('Inicio'),
      ),
    );
    await tester.pumpAndSettle();

    ofertas = (o) => respuestaJson(_pagina([_oferta()]), 200);
    conector.ultima.recibir({
      'type': 'offer.created',
      'attemptId': 'a-1',
      'serviceRequestId': 's-1',
      'expiresAt': _inicio.add(const Duration(minutes: 3)).toIso8601String(),
      'occurredAt': _inicio.toIso8601String(),
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver'));
    await tester.pumpAndSettle();
    expect(clave('tarjeta-oferta'), findsOneWidget);
  });

  testWidgets('si no puede consultar las ofertas, permite reintentar', (
    tester,
  ) async {
    ofertas = (o) => respuestaJson(<String, dynamic>{}, 503);
    await abrir(tester);
    // Tres reintentos de la política (0,2, 0,4 y 0,8 s) antes del error.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(clave('error-oferta'), findsOneWidget);
    expect(find.text('Nueva oferta'), findsNothing);

    ofertas = (o) => respuestaJson(_pagina([_oferta()]), 200);
    await tester.tap(
      find.descendant(
        of: clave('error-oferta'),
        matching: find.text('Reintentar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(clave('tarjeta-oferta'), findsOneWidget);
  });

  testWidgets('sin canal consulta cada 30 s', (tester) async {
    ofertas = (o) => respuestaJson(_pagina(const []), 200);
    conector.fallar = true;
    await abrir(tester);
    final antes = consultasDeOfertas();
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(consultasDeOfertas(), greaterThan(antes));
  });

  testWidgets('tema oscuro y texto al 200 % sin desbordes', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await abrir(tester, escalaTexto: 2);
    expect(tester.takeException(), isNull);
    final contexto = tester.element(clave('tarjeta-oferta'));
    expect(Theme.of(contexto).colorScheme, AppTheme.esquemaOscuro);
  });

  test('distancia y cuenta regresiva legibles', () {
    expect(distanciaLegible(0), 'a 0 m');
    expect(distanciaLegible(999.4), 'a 999 m');
    expect(distanciaLegible(1000), 'a 1,0 km');
    expect(distanciaLegible(12345), 'a 12,3 km');
    expect(cuentaRegresiva(const Duration(minutes: 3)), '3:00');
    expect(cuentaRegresiva(const Duration(seconds: 65)), '1:05');
    expect(cuentaRegresiva(Duration.zero), '0:00');
  });
}
