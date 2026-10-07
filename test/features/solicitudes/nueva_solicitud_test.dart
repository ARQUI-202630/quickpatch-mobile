import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/app.dart';
import 'package:quickpatch_mobile/core/network/cliente_api.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/features/solicitudes/data/proveedor_ubicacion.dart';
import 'package:quickpatch_mobile/features/solicitudes/domain/modelos.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/paginas/detalle_solicitud_page.dart';

import '../../helpers/fakes.dart';

const _categoria = 'f2b9a0c4-1111-4c0a-9a55-2f1f3d6b8e01';
const _solicitud = '01a113ed-acfd-7f1e-9ccd-5e24e2736119';

class _UbicacionFija implements ProveedorUbicacion {
  _UbicacionFija({this.falla});

  final String? falla;

  @override
  Future<Ubicacion> actual() async {
    if (falla != null) throw UbicacionNoDisponible(falla!);
    return const Ubicacion(4.6533, -74.0836);
  }
}

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

  Future<void> abrirComoCliente(
    WidgetTester tester, {
    ProveedorUbicacion? ubicacion,
  }) async {
    container = ProviderContainer(
      overrides: [
        almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
        proveedorUbicacionProvider.overrideWithValue(
          ubicacion ?? _UbicacionFija(),
        ),
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
    await tester.tap(find.byKey(const Key('campo-categoria')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plomería').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo-descripcion')),
      'Fuga de agua debajo del lavaplatos',
    );
    await tester.enterText(
      find.byKey(const Key('campo-direccion')),
      'Calle 45 # 13-20, apto 301',
    );
  }

  setUp(() {
    cuerpoEnviado = null;
    adaptador = AdaptadorFalso((opciones) {
      final ruta = opciones.path;
      if (ruta.endsWith('/v1/auth/login')) {
        return respuestaJson(loginJson(), 200);
      }
      if (ruta.endsWith('/v1/catalog/categories')) {
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
    expect(find.byType(DetalleSolicitudPage), findsOneWidget);
    expect(find.text('Buscando técnico'), findsOneWidget);
    expect(find.text('Calle 45 # 13-20, apto 301'), findsOneWidget);
  });

  testWidgets('valida los campos y exige la ubicación antes de enviar', (
    tester,
  ) async {
    await abrirComoCliente(tester);
    await tester.tap(find.byKey(const Key('boton-enviar')));
    await tester.pump();
    expect(find.text('Elige el tipo de servicio.'), findsOneWidget);
    expect(find.textContaining('al menos 10 caracteres'), findsOneWidget);
    expect(find.textContaining('Escribe la dirección'), findsOneWidget);

    await llenarFormulario(tester);
    await tester.tap(find.byKey(const Key('boton-enviar')));
    await tester.pump();
    expect(find.text('Comparte tu ubicación para continuar.'), findsOneWidget);
    expect(cuerpoEnviado, isNull);
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
}
