import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/core/session/controlador_sesion.dart';
import 'package:quickpatch_mobile/core/session/sesion.dart';
import 'package:quickpatch_mobile/features/pagos/data/repositorio_pagos.dart';
import 'package:quickpatch_mobile/features/pagos/presentation/paginas/pagar_page.dart';
import 'package:quickpatch_mobile/features/pagos/presentation/widgets/pago_cliente.dart';
import 'package:quickpatch_mobile/features/solicitudes/data/repositorio_solicitudes.dart';
import 'package:quickpatch_mobile/features/solicitudes/domain/modelos.dart';

import '../../helpers/fakes.dart';

/// Pago del cliente (RF-22, SCRUM-116; payments 1.0.0) con la pasarela
/// simulada.
Map<String, dynamic> pagoJson({
  String estado = 'pendiente',
  String? motivo,
  String? comprobante,
}) => {
  'paymentId': 'p-1',
  'serviceRequestId': 's-1',
  'status': estado,
  'amount': '185000.00',
  'reasonCode': motivo,
  'invoiceId': comprobante,
  'createdAt': '2026-10-21T15:00:00Z',
  'processedAt': null,
};

Solicitud _solicitud(EstadoSolicitud estado) => Solicitud(
  id: 's-1',
  estado: estado,
  categoriaId: 'c-1',
  descripcion: 'Fuga de agua debajo del lavaplatos',
  ubicacion: const Ubicacion(4.6765, -74.0480),
  direccion: 'Calle 93 # 13-20',
  creadaEn: DateTime.utc(2026, 10, 20, 14),
);

class _SesionFija extends ControladorSesion {
  @override
  Future<Sesion?> build() async => sesionDePrueba();
}

ResponseBody _problema(
  int status,
  String tipo, [
  Map<String, dynamic>? errores,
]) => respuestaJson({
  'type': 'https://quickpatch.internal/problems/$tipo',
  'title': tipo,
  'status': status,
  'errors': ?errores,
}, status);

void main() {
  late AdaptadorFalso adaptador;
  late List<RequestOptions> posts;
  late ResponseBody Function() alPagar;
  late ResponseBody Function() alConsultar;

  setUp(() {
    posts = [];
    alPagar = () =>
        respuestaJson(pagoJson(estado: 'aprobado', comprobante: 'i-1'), 200);
    alConsultar = () => respuestaJson(pagoJson(), 200);
    adaptador = AdaptadorFalso((o) {
      if (o.method == 'POST') {
        posts.add(o);
        return alPagar();
      }
      if (o.path.endsWith('/payment')) return alConsultar();
      return respuestaJson({}, 404);
    });
  });

  Dio dio() =>
      Dio(BaseOptions(baseUrl: 'https://qa.quickpatch.internal/api'))
        ..httpClientAdapter = adaptador;

  List<Override> overrides() => [
    repositorioPagosProvider.overrideWithValue(RepositorioPagos(dio())),
    repositorioSolicitudesProvider.overrideWithValue(
      RepositorioSolicitudes(dio()),
    ),
    controladorSesionProvider.overrideWith(_SesionFija.new),
  ];

  Finder clave(String k) => find.byKey(Key(k));

  group('sección de pago en el detalle', () {
    Future<void> abrir(WidgetTester tester, EstadoSolicitud estado) async {
      var cambios = 0;
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: overrides(),
          child: MaterialApp(
            theme: AppTheme.claro(),
            home: Scaffold(
              body: ListView(
                children: [
                  PagoCliente(
                    solicitud: _solicitud(estado),
                    alCambiar: () => cambios++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('antes de completar no aparece', (tester) async {
      await abrir(tester, EstadoSolicitud.enProgreso);

      expect(clave('pago-cliente'), findsNothing);
      expect(adaptador.ultima, isNull);
    });

    testWidgets('pendiente: el total y el botón de pagar', (tester) async {
      await abrir(tester, EstadoSolicitud.completado);

      expect(adaptador.ultima!.path, '/v1/service-requests/s-1/payment');
      expect(find.text(r'$ 185.000'), findsOneWidget);
      expect(find.text(r'Pagar $ 185.000'), findsOneWidget);
    });

    testWidgets('rechazado: el motivo y reintentar', (tester) async {
      alConsultar = () => respuestaJson(
        pagoJson(estado: 'rechazado', motivo: 'fondos_insuficientes'),
        200,
      );
      await abrir(tester, EstadoSolicitud.completado);

      expect(clave('pago-rechazado'), findsOneWidget);
      expect(find.textContaining('fondos suficientes'), findsOneWidget);
      expect(find.text('Intentar de nuevo'), findsOneWidget);
    });

    testWidgets('procesando: pide no pagar de nuevo', (tester) async {
      alConsultar = () => respuestaJson(pagoJson(estado: 'procesando'), 200);
      await abrir(tester, EstadoSolicitud.completado);

      expect(clave('pago-procesando'), findsOneWidget);
      expect(clave('boton-pagar'), findsNothing);
    });

    testWidgets('pagado: aprobado y sin botón', (tester) async {
      alConsultar = () =>
          respuestaJson(pagoJson(estado: 'aprobado', comprobante: 'i-1'), 200);
      await abrir(tester, EstadoSolicitud.pagado);

      expect(clave('pago-aprobado'), findsOneWidget);
      expect(clave('boton-pagar'), findsNothing);
    });

    testWidgets('sin pago todavía: se está preparando', (tester) async {
      alConsultar = () => _problema(404, 'pago-no-disponible');
      await abrir(tester, EstadoSolicitud.completado);

      expect(clave('pago-no-listo'), findsOneWidget);
    });

    testWidgets('otro error: no se pudo cargar', (tester) async {
      alConsultar = () => respuestaJson({}, 500);
      await abrir(tester, EstadoSolicitud.completado);

      expect(clave('error-pago'), findsOneWidget);
    });
  });

  group('pantalla de pagar', () {
    late bool? resultado;

    Future<void> abrir(WidgetTester tester) async {
      resultado = null;
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    resultado = await context.push<bool>('/pagar'),
                child: const Text('ir'),
              ),
            ),
          ),
          GoRoute(
            path: '/pagar',
            builder: (_, _) => const PagarPage(solicitudId: 's-1'),
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
      await tester.tap(find.text('ir'));
      await tester.pumpAndSettle();
    }

    Future<void> llenarYPagar(WidgetTester tester, String tarjeta) async {
      await tester.tap(clave('tarjeta-$tarjeta'));
      await tester.enterText(clave('campo-documento'), '52123456');
      await tester.enterText(clave('campo-correo'), 'ana@correo.com');
      await tester.ensureVisible(clave('confirmar-pago'));
      await tester.tap(clave('confirmar-pago'));
      await tester.pumpAndSettle();
    }

    testWidgets('aprobado: solo viaja el token y vuelve con true', (
      tester,
    ) async {
      await abrir(tester);
      expect(clave('total-a-pagar'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: clave('campo-nombre'),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        'Ana Gómez',
      );

      await llenarYPagar(tester, '4242424242424242');

      final cuerpo = posts.single.data as Map<String, dynamic>;
      expect(cuerpo['paymentToken'], startsWith('tok_sim_aprobada_'));
      expect(cuerpo['billing'], {
        'name': 'Ana Gómez',
        'documentType': 'CC',
        'documentNumber': '52123456',
        'email': 'ana@correo.com',
      });
      expect(jsonEncode(cuerpo), isNot(contains('4242')));
      expect(cuerpo.containsKey('amount'), isFalse);
      expect(resultado, isTrue);
      expect(find.textContaining('terminada en 4242'), findsOneWidget);
    });

    testWidgets('rechazado: se queda con el motivo y borra el CVV', (
      tester,
    ) async {
      alPagar = () => respuestaJson(
        pagoJson(estado: 'rechazado', motivo: 'fondos_insuficientes'),
        200,
      );
      await abrir(tester);

      await llenarYPagar(tester, '4000000000000002');

      expect(clave('error-pago'), findsOneWidget);
      expect(find.textContaining('fondos suficientes'), findsOneWidget);
      expect(resultado, isNull);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: clave('campo-cvv'),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        isEmpty,
      );
    });

    for (final (tipo, status) in [
      ('pasarela-sin-respuesta', 502),
      ('pago-en-curso', 409),
      ('ya-pagado', 409),
    ]) {
      testWidgets('$status $tipo: vuelve al detalle con el aviso', (
        tester,
      ) async {
        alPagar = () => _problema(status, tipo);
        await abrir(tester);

        await llenarYPagar(tester, '4000000000000119');

        expect(resultado, isTrue);
        expect(find.byType(SnackBar), findsOneWidget);
      });
    }

    testWidgets('formulario vacío: no tokeniza ni envía', (tester) async {
      await abrir(tester);
      await tester.enterText(clave('campo-nombre'), '');
      await tester.ensureVisible(clave('confirmar-pago'));
      await tester.tap(clave('confirmar-pago'));
      await tester.pumpAndSettle();

      expect(find.text('Escribe el número de la tarjeta.'), findsOneWidget);
      expect(find.text('Escribe entre 2 y 150 caracteres.'), findsOneWidget);
      expect(posts, isEmpty);
    });

    testWidgets('tarjeta que no es de prueba: error en el número, sin envío', (
      tester,
    ) async {
      await abrir(tester);
      await tester.enterText(clave('campo-numero'), '5555 5555 5555 4444');
      await tester.enterText(clave('campo-vencimiento'), '12/30');
      await tester.enterText(clave('campo-cvv'), '123');
      await tester.enterText(clave('campo-documento'), '52123456');
      await tester.enterText(clave('campo-correo'), 'ana@correo.com');
      await tester.ensureVisible(clave('confirmar-pago'));
      await tester.tap(clave('confirmar-pago'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('solo se aceptan las tarjetas de prueba'),
        findsOneWidget,
      );
      expect(posts, isEmpty);
    });

    testWidgets('400 del servidor: marca el campo del comprobante', (
      tester,
    ) async {
      alPagar = () => _problema(400, 'validacion', {
        'billing.email': ['Debe ser un correo válido.'],
      });
      await abrir(tester);
      await tester.tap(clave('campo-tipo-documento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NIT').last);
      await tester.pumpAndSettle();

      await llenarYPagar(tester, '4242424242424242');

      expect(find.text('Debe ser un correo válido.'), findsOneWidget);
      expect((posts.single.data as Map)['billing']['documentType'], 'NIT');
      expect(resultado, isNull);
    });
  });
}
