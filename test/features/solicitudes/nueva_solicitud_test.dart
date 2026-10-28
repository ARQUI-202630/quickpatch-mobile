import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/app.dart';
import 'package:quickpatch_mobile/app/shell/actividad_page.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/core/geo/mapa_localidades.dart';
import 'package:quickpatch_mobile/core/geo/repositorio_localidades.dart';
import 'package:quickpatch_mobile/core/network/cliente_api.dart';
import 'package:quickpatch_mobile/core/realtime/canal_tiempo_real.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/features/solicitudes/data/proveedor_ubicacion.dart';
import 'package:quickpatch_mobile/features/solicitudes/domain/modelos.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/paginas/detalle_solicitud_page.dart';
import 'package:quickpatch_mobile/shared/widgets/mapa_bogota.dart';

import '../../helpers/fakes.dart';

const _categoria = 'f2b9a0c4-1111-4c0a-9a55-2f1f3d6b8e01';
const _solicitud = '01a113ed-acfd-7f1e-9ccd-5e24e2736119';

class _UbicacionFija implements ProveedorUbicacion {
  _UbicacionFija({this.falla, this.fallaInesperada = false});

  final String? falla;

  /// Falla con una excepción que no es [UbicacionNoDisponible].
  final bool fallaInesperada;

  @override
  Future<Ubicacion> actual() async {
    if (falla != null) throw UbicacionNoDisponible(falla!);
    if (fallaInesperada) throw Exception('GPS sin respuesta');
    return const Ubicacion(4.6533, -74.0836);
  }
}

/// Punto que reconoce el geocodificador para la dirección (1.3.0).
Map<String, dynamic> _vistaPreviaJson() => {
  'location': {'latitude': 4.6486, 'longitude': -74.063},
  'locality': {'code': '02', 'name': 'Chapinero'},
  'matchedAddress': 'Calle 45, Chapinero, Bogotá',
};

final _mapa = MapaLocalidades.desdeGeoJson(
  File(rutaMapaLocalidades).readAsStringSync(),
);

Map<String, dynamic> _solicitudJson() => {
  'id': _solicitud,
  'status': 'buscando_tecnico',
  'categoryId': _categoria,
  'technicianId': null,
  'description': 'Fuga de agua debajo del lavaplatos',
  'location': {'latitude': 4.6533, 'longitude': -74.0836},
  'addressText': 'Calle 45 # 13-20, apto 301',
  'createdAt': '2026-10-07T15:00:00Z',
};

void main() {
  late AdaptadorFalso adaptador;
  late ProviderContainer container;
  Map<String, dynamic>? cuerpoEnviado;
  Map<String, dynamic>? cuerpoVistaPrevia;
  late ResponseBody Function() vistaPrevia;
  var rolLogin = 'cliente';

  Future<void> abrirComoCliente(
    WidgetTester tester, {
    ProveedorUbicacion? ubicacion,
  }) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    // Teléfono de 400 x 1200 px lógicos: el formulario cabe sin desplazar.
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
        conectorWsProvider.overrideWithValue(ConectorWsFalso().call),
        proveedorUbicacionProvider.overrideWithValue(
          ubicacion ?? _UbicacionFija(),
        ),
        mapaLocalidadesProvider.overrideWith((ref) async => _mapa),
      ],
    );
    addTearDown(container.dispose);
    container.read(clienteApiProvider).httpClientAdapter = adaptador;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QuickpatchApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo-email')),
      'ana@correo.com',
    );
    await tester.enterText(find.byKey(const Key('campo-password')), 'secreta');
    await tester.tap(find.byKey(const Key('boton-ingresar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva solicitud'));
    await tester.pumpAndSettle();
  }

  Future<void> llenarFormulario(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('campo-categoria')));
    await tester.tap(find.byKey(const Key('campo-categoria')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plomería').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('campo-descripcion')));
    await tester.enterText(
      find.byKey(const Key('campo-descripcion')),
      'Fuga de agua debajo del lavaplatos',
    );
    await tester.ensureVisible(find.byKey(const Key('campo-direccion')));
    await tester.enterText(
      find.byKey(const Key('campo-direccion')),
      'Calle 45 # 13-20, apto 301',
    );
  }

  setUp(() {
    rolLogin = 'cliente';
    cuerpoEnviado = null;
    cuerpoVistaPrevia = null;
    vistaPrevia = () => respuestaJson(_vistaPreviaJson(), 200);
    adaptador = AdaptadorFalso((opciones) {
      final ruta = opciones.path;
      if (ruta.endsWith('/v1/service-requests/location-preview')) {
        cuerpoVistaPrevia =
            jsonDecode(jsonEncode(opciones.data)) as Map<String, dynamic>;
        return vistaPrevia();
      }
      if (ruta.endsWith('/v1/auth/login')) {
        return respuestaJson(loginJson(rol: rolLogin), 200);
      }
      if (ruta.endsWith('/v1/service-requests/categories')) {
        return respuestaJson([
          {'id': _categoria, 'name': 'Plomería', 'description': null},
        ], 200);
      }
      if (ruta.endsWith('/v1/service-requests') && opciones.method == 'POST') {
        cuerpoEnviado =
            jsonDecode(jsonEncode(opciones.data)) as Map<String, dynamic>;
        return respuestaJson(_solicitudJson(), 201);
      }
      if (ruta.endsWith('/v1/service-requests/$_solicitud')) {
        return respuestaJson(_solicitudJson(), 200);
      }
      return respuestaJson({
        'status': 404,
        'type': 'problems/no-encontrado',
      }, 404);
    });
  });

  testWidgets('el cliente crea una solicitud y ve que se busca técnico', (
    tester,
  ) async {
    await abrirComoCliente(tester);
    await llenarFormulario(tester);
    await tester.tap(find.byKey(const Key('boton-ubicacion')));
    await tester.pumpAndSettle();
    expect(find.textContaining('4.65330, -74.08360'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton-enviar')));
    await tester.pumpAndSettle();

    expect(cuerpoEnviado, {
      'categoryId': _categoria,
      'description': 'Fuga de agua debajo del lavaplatos',
      'location': {'latitude': 4.6533, 'longitude': -74.0836},
      'addressText': 'Calle 45 # 13-20, apto 301',
    });
    expect(adaptador.ultima!.headers['Authorization'], 'Bearer token-acceso');
    // Con GPS no hace falta confirmar la dirección.
    expect(cuerpoVistaPrevia, isNull);
    expect(find.byType(DetalleSolicitudPage), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('estado-solicitud')),
        matching: find.text('Buscando técnico'),
        matchRoot: true,
      ),
      findsOneWidget,
    );
    expect(find.text('Calle 45 # 13-20, apto 301'), findsOneWidget);
  });

  testWidgets('valida los campos antes de enviar', (tester) async {
    await abrirComoCliente(tester);
    await tester.tap(find.byKey(const Key('boton-enviar')));
    await tester.pump();
    expect(find.text('Elige el tipo de servicio.'), findsOneWidget);
    expect(find.textContaining('al menos 10 caracteres'), findsOneWidget);
    expect(find.textContaining('Escribe la dirección'), findsOneWidget);
    expect(cuerpoVistaPrevia, isNull);
    expect(cuerpoEnviado, isNull);
  });

  group('sin GPS (SCRUM-457, service-request 1.3.0)', () {
    Finder clave(String k) => find.byKey(Key(k));

    Future<void> enviarSinGps(WidgetTester tester) async {
      await llenarFormulario(tester);
      await tester.ensureVisible(clave('boton-enviar'));
      await tester.tap(clave('boton-enviar'));
      await tester.pumpAndSettle();
    }

    testWidgets('pregunta «¿Es aquí?» y crea la solicitud con ese punto', (
      tester,
    ) async {
      await abrirComoCliente(tester);
      await enviarSinGps(tester);

      expect(cuerpoVistaPrevia, {'addressText': 'Calle 45 # 13-20, apto 301'});
      expect(cuerpoEnviado, isNull);
      expect(find.text('¿Es aquí?'), findsOneWidget);
      expect(
        tester.widget<Text>(clave('direccion-reconocida')).data,
        'Calle 45, Chapinero, Bogotá',
      );
      expect(
        tester.widget<Text>(clave('localidad-reconocida')).data,
        'Localidad: Chapinero',
      );
      final mapa = tester.widget<MapaBogota>(find.byType(MapaBogota));
      expect(mapa.alTocar, isNull);
      expect(mapa.elegidas, {'02'});
      expect(mapa.punto, MapaLocalidades.proyectar(-74.063, 4.6486));

      await tester.tap(clave('boton-si-es-aqui'));
      await tester.pumpAndSettle();
      expect(cuerpoEnviado, {
        'categoryId': _categoria,
        'description': 'Fuga de agua debajo del lavaplatos',
        'location': {'latitude': 4.6486, 'longitude': -74.063},
        'addressText': 'Calle 45 # 13-20, apto 301',
      });
      expect(find.byType(DetalleSolicitudPage), findsOneWidget);
    });

    testWidgets('si no es ahí no crea nada y pide la ubicación', (
      tester,
    ) async {
      await abrirComoCliente(tester);
      await enviarSinGps(tester);
      await tester.tap(clave('boton-no-es-aqui'));
      await tester.pumpAndSettle();

      expect(cuerpoEnviado, isNull);
      expect(find.text('¿Es aquí?'), findsNothing);
      expect(
        find.text(
          'Toca «Usar mi ubicación» para que el técnico llegue al lugar '
          'correcto.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('422 direccion-no-encontrada invita a compartir la ubicación', (
      tester,
    ) async {
      vistaPrevia = () => respuestaJson({
        'status': 422,
        'type': 'https://quickpatch.internal/problems/direccion-no-encontrada',
      }, 422);
      await abrirComoCliente(tester);
      await enviarSinGps(tester);

      expect(find.text('¿Es aquí?'), findsNothing);
      expect(clave('mensaje-error'), findsOneWidget);
      expect(
        find.textContaining('No encontramos esa dirección en Bogotá.'),
        findsOneWidget,
      );
      expect(find.textContaining('«Usar mi ubicación»'), findsWidgets);
      expect(cuerpoEnviado, isNull);
    });

    testWidgets('422 ubicacion-fuera-de-cobertura lo explica', (tester) async {
      vistaPrevia = () => respuestaJson({
        'status': 422,
        'type':
            'https://quickpatch.internal/problems/ubicacion-fuera-de-cobertura',
      }, 422);
      await abrirComoCliente(tester);
      await enviarSinGps(tester);

      expect(find.textContaining('queda fuera de Bogotá'), findsOneWidget);
      expect(cuerpoEnviado, isNull);
    });

    testWidgets('si luego comparte la ubicación ya no pregunta', (
      tester,
    ) async {
      await abrirComoCliente(tester);
      await enviarSinGps(tester);
      await tester.tap(clave('boton-no-es-aqui'));
      await tester.pumpAndSettle();

      cuerpoVistaPrevia = null;
      await tester.tap(clave('boton-ubicacion'));
      await tester.pumpAndSettle();
      await tester.tap(clave('boton-enviar'));
      await tester.pumpAndSettle();
      expect(cuerpoVistaPrevia, isNull);
      expect(cuerpoEnviado?['location'], {
        'latitude': 4.6533,
        'longitude': -74.0836,
      });
    });

    testWidgets('tema oscuro y texto al 200 % sin desbordes', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await abrirComoCliente(tester);
      // El texto grande se prueba en el formulario y en la confirmación.
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      await enviarSinGps(tester);
      expect(tester.takeException(), isNull);
      expect(clave('confirmar-ubicacion'), findsOneWidget);
      final contexto = tester.element(clave('confirmar-ubicacion'));
      expect(Theme.of(contexto).colorScheme, AppTheme.esquemaOscuro);
    });
  });

  test('sin ubicación el cuerpo no lleva location (1.3.0)', () {
    const sinGps = NuevaSolicitud(
      categoriaId: _categoria,
      descripcion: ' Fuga ',
      direccion: ' Calle 45 # 13-20 ',
    );
    expect(sinGps.toJson(), {
      'categoryId': _categoria,
      'description': 'Fuga',
      'addressText': 'Calle 45 # 13-20',
    });
  });

  testWidgets('muestra por qué no se pudo obtener la ubicación', (
    tester,
  ) async {
    await abrirComoCliente(
      tester,
      ubicacion: _UbicacionFija(falla: 'Activa la ubicación del teléfono.'),
    );
    await tester.tap(find.byKey(const Key('boton-ubicacion')));
    await tester.pumpAndSettle();
    expect(find.text('Activa la ubicación del teléfono.'), findsOneWidget);
  });

  testWidgets('traduce el error del servidor (categoría no disponible)', (
    tester,
  ) async {
    await abrirComoCliente(tester);
    adaptador.responder = (_) => respuestaJson({
      'status': 422,
      'type': 'https://quickpatch.internal/problems/categoria-no-disponible',
    }, 422);
    await llenarFormulario(tester);
    await tester.tap(find.byKey(const Key('boton-ubicacion')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton-enviar')));
    await tester.pumpAndSettle();

    expect(
      find.text('Esa categoría ya no está disponible. Elige otra.'),
      findsOneWidget,
    );
  });

  testWidgets('si Catalog falla muestra el error y reintenta', (tester) async {
    final normal = adaptador.responder;
    var catalogoArriba = false;
    adaptador.responder = (o) =>
        o.path.endsWith('/v1/service-requests/categories') && !catalogoArriba
        ? respuestaJson({'status': 503}, 503)
        : normal(o);
    await abrirComoCliente(tester);
    expect(find.text('No pudimos cargar las categorías.'), findsOneWidget);

    catalogoArriba = true;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('campo-categoria')), findsOneWidget);
  });

  testWidgets('un fallo inesperado del GPS muestra un mensaje genérico', (
    tester,
  ) async {
    await abrirComoCliente(
      tester,
      ubicacion: _UbicacionFija(fallaInesperada: true),
    );
    await tester.tap(find.byKey(const Key('boton-ubicacion')));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos obtener tu ubicación.'), findsOneWidget);
  });

  testWidgets(
    'el detalle se actualiza al deslizar y atrás vuelve a Mis solicitudes',
    (tester) async {
      await abrirComoCliente(tester);
      await llenarFormulario(tester);
      await tester.tap(find.byKey(const Key('boton-ubicacion')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('boton-enviar')));
      await tester.pumpAndSettle();
      expect(find.byType(DetalleSolicitudPage), findsOneWidget);

      var consultas = 0;
      final normal = adaptador.responder;
      adaptador.responder = (o) {
        if (o.path.endsWith('/v1/service-requests/$_solicitud')) consultas++;
        return normal(o);
      };
      await tester.fling(
        find.byKey(const Key('estado-solicitud')),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(consultas, 1);

      // Recién creada no hay pantalla anterior: la flecha lleva a Mis solicitudes
      // (SCRUM-617).
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(ActividadPage), findsOneWidget);
    },
  );

  test('Solicitud y estados se leen según el contrato', () {
    final s = Solicitud.desdeJson(_solicitudJson());
    expect(s.estado, EstadoSolicitud.buscandoTecnico);
    expect(s.tecnicoId, isNull);
    expect(s.ubicacion.latitud, 4.6533);
    expect(
      EstadoSolicitud.values.map((e) => EstadoSolicitud.desdeValor(e.valor)),
      EstadoSolicitud.values,
    );
  });

  testWidgets('el cliente no ve el campo de la sede', (tester) async {
    await abrirComoCliente(tester);

    expect(find.byKey(const Key('campo-sede')), findsNothing);
  });

  testWidgets('la empresa indica la sede y la envía como siteName (SCRUM-74)', (
    tester,
  ) async {
    rolLogin = 'empresa_contacto';
    await abrirComoCliente(tester);
    await llenarFormulario(tester);
    await tester.ensureVisible(find.byKey(const Key('campo-sede')));
    await tester.enterText(find.byKey(const Key('campo-sede')), 'S');
    await tester.tap(find.byKey(const Key('boton-ubicacion')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('boton-enviar')));
    await tester.tap(find.byKey(const Key('boton-enviar')));
    await tester.pumpAndSettle();
    expect(cuerpoEnviado, isNull);
    expect(find.textContaining('nombre de la sede'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo-sede')), ' Sede Norte ');
    await tester.ensureVisible(find.byKey(const Key('boton-enviar')));
    await tester.tap(find.byKey(const Key('boton-enviar')));
    await tester.pumpAndSettle();

    expect(cuerpoEnviado!['siteName'], 'Sede Norte');
    expect(cuerpoEnviado!.containsKey('clientType'), isFalse);
    expect(cuerpoEnviado!.containsKey('companyId'), isFalse);
  });
}
