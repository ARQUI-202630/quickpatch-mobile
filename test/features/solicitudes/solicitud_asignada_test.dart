import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/app.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/core/errors/app_exception.dart';
import 'package:quickpatch_mobile/core/errors/codigo_error.dart';
import 'package:quickpatch_mobile/core/geo/localidad.dart';
import 'package:quickpatch_mobile/core/geo/mapa_localidades.dart';
import 'package:quickpatch_mobile/core/geo/repositorio_localidades.dart';
import 'package:quickpatch_mobile/core/network/cliente_api.dart';
import 'package:quickpatch_mobile/core/network/politica_reintento.dart';
import 'package:quickpatch_mobile/core/realtime/canal_tiempo_real.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';
import 'package:quickpatch_mobile/features/solicitudes/data/repositorio_solicitudes.dart';
import 'package:quickpatch_mobile/features/solicitudes/domain/modelos.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/paginas/solicitud_asignada_page.dart';
import 'package:quickpatch_mobile/shared/widgets/mapa_bogota.dart';

import '../../helpers/fakes.dart';

/// SCRUM-92: detalle de la solicitud asignada, para el técnico.
final _mapa = MapaLocalidades.desdeGeoJson(
  File(rutaMapaLocalidades).readAsStringSync(),
);

Solicitud _solicitud({ClienteSolicitud? cliente}) => Solicitud(
  id: 's-1',
  estado: EstadoSolicitud.asignado,
  categoriaId: 'c-1',
  descripcion: 'Fuga de agua debajo del lavaplatos',
  // Parque de la 93: Chapinero.
  ubicacion: const Ubicacion(4.6765, -74.0480),
  direccion: 'Calle 93 # 13-20, apto 502',
  creadaEn: DateTime.utc(2026, 10, 7, 15),
  asignadaEn: DateTime.utc(2026, 10, 7, 15, 20),
  cliente:
      cliente ??
      const ClienteSolicitud(
        id: 'u-9',
        nombre: 'Laura Gómez',
        telefono: '3001234567',
      ),
);

void main() {
  late int consultas;
  late String? copiado;

  setUp(() {
    consultas = 0;
    copiado = null;
  });

  Future<void> abrir(
    WidgetTester tester,
    Future<Solicitud> Function() obtener, {
    bool conMapa = true,
    ThemeData? tema,
    double escalaTexto = 1,
  }) async {
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = escalaTexto;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (llamada) async {
        if (llamada.method == 'Clipboard.setData') {
          copiado = (llamada.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        // La misma política de reintentos de main.dart.
        retry: politicaReintento,
        overrides: [
          solicitudProvider.overrideWith((ref, id) {
            consultas++;
            return obtener();
          }),
          categoriasProvider.overrideWith(
            (ref) async => const [Categoria(id: 'c-1', nombre: 'Plomería')],
          ),
          localidadesProvider.overrideWith(
            (ref) async => const [
              Localidad(codigo: '01', nombre: 'Usaquén'),
              Localidad(codigo: '02', nombre: 'Chapinero'),
            ],
          ),
          mapaLocalidadesProvider.overrideWith(
            (ref) => conMapa
                ? Future.value(_mapa)
                : Future<MapaLocalidades>.error(const FormatException('x')),
          ),
        ],
        child: MaterialApp(
          theme: tema ?? AppTheme.claro(),
          home: const SolicitudAsignadaPage(id: 's-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder texto(String clave) => find.byKey(Key(clave));

  testWidgets(
    'muestra el servicio, el cliente y la dirección con su localidad',
    (tester) async {
      await abrir(tester, () async => _solicitud());

      expect(find.text('Servicio asignado'), findsOneWidget);
      expect(tester.widget<Text>(texto('categoria')).data, 'Plomería');
      expect(find.text(EstadoSolicitud.asignado.etiqueta), findsOneWidget);
      expect(tester.widget<Text>(texto('cliente-nombre')).data, 'Laura Gómez');
      expect(
        tester.widget<SelectableText>(texto('cliente-telefono')).data,
        '3001234567',
      );
      expect(
        tester.widget<Text>(texto('descripcion')).data,
        'Fuga de agua debajo del lavaplatos',
      );
      expect(
        tester.widget<SelectableText>(texto('direccion')).data,
        'Calle 93 # 13-20, apto 502',
      );
      expect(
        tester.widget<Text>(texto('localidad')).data,
        'Localidad: Chapinero',
      );
    },
  );

  testWidgets('el mapa es de solo lectura, marca el punto y su localidad', (
    tester,
  ) async {
    await abrir(tester, () async => _solicitud());

    final mapa = tester.widget<MapaBogota>(find.byType(MapaBogota));
    expect(mapa.alTocar, isNull);
    expect(mapa.elegidas, {'02'});
    expect(mapa.punto, MapaLocalidades.proyectar(-74.0480, 4.6765));
    expect(mapa.encuadreInicial!.contains(mapa.punto!), isTrue);
    expect(find.byTooltip('Ver toda la ciudad'), findsOneWidget);
  });

  testWidgets('copia la dirección para usarla en otra app', (tester) async {
    await abrir(tester, () async => _solicitud());

    await tester.ensureVisible(texto('boton-copiar-direccion'));
    await tester.tap(texto('boton-copiar-direccion'));
    await tester.pumpAndSettle();
    expect(copiado, 'Calle 93 # 13-20, apto 502');
    expect(find.text('Dirección copiada'), findsOneWidget);
  });

  testWidgets('iniciar el servicio queda deshabilitado hasta la cotización', (
    tester,
  ) async {
    await abrir(tester, () async => _solicitud());

    final boton = tester.widget<FilledButton>(texto('boton-iniciar-servicio'));
    expect(boton.onPressed, isNull);
    expect(
      find.text('Podrás iniciarlo cuando el cliente acepte tu cotización.'),
      findsOneWidget,
    );
  });

  testWidgets('sin nombre ni teléfono del cliente (Identity no respondió)', (
    tester,
  ) async {
    await abrir(
      tester,
      () async => _solicitud(cliente: const ClienteSolicitud(id: 'u-9')),
    );

    expect(find.text('Nombre no disponible por ahora'), findsOneWidget);
    expect(find.text('Teléfono no disponible por ahora'), findsOneWidget);
  });

  testWidgets('sin el asset del mapa muestra la dirección igual', (
    tester,
  ) async {
    await abrir(tester, () async => _solicitud(), conMapa: false);

    expect(find.byType(MapaBogota), findsNothing);
    expect(texto('direccion'), findsOneWidget);
    expect(texto('boton-copiar-direccion'), findsOneWidget);
  });

  testWidgets('un 403 explica que los datos ya no están a su cargo', (
    tester,
  ) async {
    await abrir(
      tester,
      () async => throw const AppException(CodigoError.forbidden, status: 403),
    );
    expect(texto('sin-acceso'), findsOneWidget);
    expect(find.text('Calle 93 # 13-20, apto 502'), findsNothing);
    // Un 4xx no se reintenta: la pantalla no se queda cargando.
    expect(consultas, 1);
  });

  testWidgets('un 404 dice que no encontró el servicio', (tester) async {
    await abrir(
      tester,
      () async => throw const AppException(CodigoError.notFound, status: 404),
    );
    expect(texto('no-encontrada'), findsOneWidget);
    expect(consultas, 1);
  });

  testWidgets('otro error permite reintentar', (tester) async {
    var fallar = true;
    await abrir(tester, () async {
      if (fallar) throw const AppException(CodigoError.sinConexion);
      return _solicitud();
    });
    expect(texto('error-solicitud'), findsOneWidget);

    fallar = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    // Riverpod también reintenta solo; aquí importa que el botón recargue.
    expect(texto('cliente-nombre'), findsOneWidget);
    expect(consultas, greaterThan(1));
  });

  testWidgets('tema oscuro y texto al 200 % sin desbordes', (tester) async {
    await abrir(
      tester,
      () async => _solicitud(),
      tema: AppTheme.oscuro(),
      escalaTexto: 2,
    );
    expect(tester.takeException(), isNull);
  });

  group('aviso de asignación en el shell del técnico', () {
    testWidgets('el aviso de asignado abre el detalle del servicio', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 3600);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final conector = ConectorWsFalso();
      final memoria = AlmacenSeguroEnMemoria();
      await AlmacenSesion(memoria)
          .guardar(sesionDePrueba(rol: RolUsuario.tecnico));
      final container = ProviderContainer(
        overrides: [
          almacenSeguroProvider.overrideWithValue(memoria),
          conectorWsProvider.overrideWithValue(conector.call),
          solicitudProvider.overrideWith((ref, id) async => _solicitud()),
          categoriasProvider.overrideWith(
            (ref) async => const [Categoria(id: 'c-1', nombre: 'Plomería')],
          ),
          localidadesProvider.overrideWith((ref) async => const []),
          mapaLocalidadesProvider.overrideWith((ref) async => _mapa),
        ],
      );
      addTearDown(container.dispose);
      container.read(clienteApiProvider).httpClientAdapter = AdaptadorFalso(
        (o) => respuestaJson(<String, dynamic>{}, 404),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const QuickpatchApp(),
        ),
      );
      await tester.pumpAndSettle();
      conector.ultima.recibir({'type': 'auth.accepted'});
      await tester.pumpAndSettle();

      // Otros avisos no muestran nada.
      conector.ultima.recibir({
        'type': 'service-request.status-changed',
        'serviceRequestId': 's-1',
        'status': 'en_progreso',
      });
      await tester.pumpAndSettle();
      expect(find.text('Te asignaron un servicio.'), findsNothing);

      conector.ultima.recibir({
        'type': 'service-request.status-changed',
        'serviceRequestId': 's-1',
        'status': 'asignado',
      });
      await tester.pumpAndSettle();
      expect(find.text('Te asignaron un servicio.'), findsOneWidget);

      await tester.tap(find.text('Ver'));
      await tester.pumpAndSettle();
      expect(find.byType(SolicitudAsignadaPage), findsOneWidget);
      expect(find.text('Laura Gómez'), findsOneWidget);
    });
  });
}
