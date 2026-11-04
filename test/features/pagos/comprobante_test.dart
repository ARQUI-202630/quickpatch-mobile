import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/features/pagos/data/compartir_archivo.dart';
import 'package:quickpatch_mobile/features/pagos/data/repositorio_pagos.dart';
import 'package:quickpatch_mobile/features/pagos/domain/pago.dart';
import 'package:quickpatch_mobile/features/pagos/presentation/paginas/comprobante_page.dart';
import 'package:quickpatch_mobile/features/pagos/presentation/widgets/pago_cliente.dart';
import 'package:quickpatch_mobile/features/solicitudes/domain/modelos.dart';

import '../../helpers/fakes.dart';

/// Comprobante del pago aprobado (RF-24, SCRUM-494; payments 1.1.0).
Map<String, dynamic> comprobanteJson({String tipo = 'NIT'}) => {
  'invoiceId': 'i-1',
  'invoiceNumber': 'QP-20261021-1B2C3D4E5F',
  'paymentId': 'p-1',
  'serviceRequestId': 's-1',
  'payer': {
    'name': 'Inversiones Andinas S.A.S.',
    'documentType': tipo,
    'documentNumber': '900123456-7',
    'email': 'pagos@andinas.com.co',
  },
  'amount': '185000.00',
  'currency': 'COP',
  'concept': 'Servicio técnico de la solicitud s-1',
  'issuedAt': '2026-10-21T15:02:10Z',
  'fiscalValidity': false,
};

final _pdf = Uint8List.fromList('%PDF-1.4 comprobante'.codeUnits);

void main() {
  late AdaptadorFalso adaptador;
  late List<RequestOptions> peticiones;
  late ResponseBody Function() alPedirJson;
  late ResponseBody Function() alPedirPdf;
  late List<(Uint8List, String, String)> compartidos;

  setUp(() {
    peticiones = [];
    compartidos = [];
    alPedirJson = () => respuestaJson(comprobanteJson(), 200);
    alPedirPdf = () => ResponseBody.fromBytes(
      _pdf,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/pdf'],
      },
    );
    adaptador = AdaptadorFalso((o) {
      peticiones.add(o);
      if (o.path.endsWith('/invoice')) {
        return o.headers['Accept'] == 'application/pdf'
            ? alPedirPdf()
            : alPedirJson();
      }
      return respuestaJson({
        'paymentId': 'p-1',
        'serviceRequestId': 's-1',
        'status': 'aprobado',
        'amount': '185000.00',
        'reasonCode': null,
        'invoiceId': 'i-1',
        'createdAt': '2026-10-21T15:00:00Z',
        'processedAt': '2026-10-21T15:02:10Z',
      }, 200);
    });
  });

  List<Override> overrides() => [
    repositorioPagosProvider.overrideWithValue(
      RepositorioPagos(
        Dio(BaseOptions(baseUrl: 'https://qa.quickpatch.internal/api'))
          ..httpClientAdapter = adaptador,
      ),
    ),
    compartirArchivoProvider.overrideWithValue(
      ({
        required Uint8List bytes,
        required String nombre,
        required String tipo,
      }) async => compartidos.add((bytes, nombre, tipo)),
    ),
  ];

  Finder clave(String k) => find.byKey(Key(k));

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: overrides(),
        child: MaterialApp(
          theme: AppTheme.claro(),
          home: const ComprobantePage(pagoId: 'p-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('el comprobante se lee según el contrato', () {
    final comprobante = Comprobante.desdeJson(comprobanteJson());

    expect(comprobante.numero, 'QP-20261021-1B2C3D4E5F');
    expect(comprobante.pagador.tipoDocumento, TipoDocumento.nit);
    expect(comprobante.monto.formatear(), r'$ 185.000');
    expect(comprobante.emitidoEn, DateTime.utc(2026, 10, 21, 15, 2, 10));
    expect(comprobante.archivoPdf, 'QP-20261021-1B2C3D4E5F.pdf');
    expect(
      () => Comprobante.desdeJson(comprobanteJson(tipo: 'RUT')),
      throwsFormatException,
    );
  });

  testWidgets('muestra el número, el total, el NIT y el rótulo fiscal', (
    tester,
  ) async {
    await abrir(tester);

    expect(peticiones.single.path, '/v1/payments/p-1/invoice');
    expect(find.text('QP-20261021-1B2C3D4E5F'), findsOneWidget);
    expect(find.text(r'$ 185.000 COP'), findsOneWidget);
    expect(find.text('NIT 900123456-7'), findsOneWidget);
    expect(find.text('Inversiones Andinas S.A.S.'), findsOneWidget);
    expect(clave('sin-validez-fiscal'), findsOneWidget);
  });

  testWidgets('compartir PDF: pide el PDF y lo pasa al menú del sistema', (
    tester,
  ) async {
    await abrir(tester);

    await tester.ensureVisible(clave('compartir-pdf'));
    await tester.tap(clave('compartir-pdf'));
    await tester.pumpAndSettle();

    expect(peticiones.last.headers['Accept'], 'application/pdf');
    expect(peticiones.last.responseType, ResponseType.bytes);
    final (bytes, nombre, tipo) = compartidos.single;
    expect(bytes, _pdf);
    expect(nombre, 'QP-20261021-1B2C3D4E5F.pdf');
    expect(tipo, 'application/pdf');
  });

  testWidgets('si el PDF falla, avisa y no comparte', (tester) async {
    alPedirPdf = () => respuestaJson({}, 500);
    await abrir(tester);

    await tester.ensureVisible(clave('compartir-pdf'));
    await tester.tap(clave('compartir-pdf'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(compartidos, isEmpty);
  });

  testWidgets('sin comprobante: el error y reintentar', (tester) async {
    alPedirJson = () => respuestaJson({
      'type': 'https://quickpatch.internal/problems/no-encontrado',
      'title': 'El comprobante no existe.',
      'status': 404,
    }, 404);
    await abrir(tester);

    expect(clave('error-comprobante'), findsOneWidget);
    alPedirJson = () => respuestaJson(comprobanteJson(), 200);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('QP-20261021-1B2C3D4E5F'), findsOneWidget);
  });

  testWidgets('el pago aprobado lleva al comprobante', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: ListView(
              children: [
                PagoCliente(
                  solicitud: Solicitud(
                    id: 's-1',
                    estado: EstadoSolicitud.pagado,
                    categoriaId: 'c-1',
                    descripcion: 'Fuga de agua debajo del lavaplatos',
                    ubicacion: const Ubicacion(4.6765, -74.0480),
                    direccion: 'Calle 93 # 13-20',
                    creadaEn: DateTime.utc(2026, 10, 20, 14),
                  ),
                  alCambiar: () {},
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/pagos/:id/comprobante',
          builder: (_, state) =>
              ComprobantePage(pagoId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: overrides(),
        child: MaterialApp.router(
          theme: AppTheme.claro(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(clave('ver-comprobante'));
    await tester.pumpAndSettle();

    expect(find.byType(ComprobantePage), findsOneWidget);
    expect(peticiones.last.path, '/v1/payments/p-1/invoice');
  });
}
