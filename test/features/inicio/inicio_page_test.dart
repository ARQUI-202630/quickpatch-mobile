import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/app.dart';
import 'package:quickpatch_mobile/core/network/cliente_api.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';
import 'package:quickpatch_mobile/core/session/sesion.dart';
import 'package:quickpatch_mobile/features/inicio/presentation/paginas/actividad_page.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/paginas/nueva_solicitud_page.dart';

import '../../helpers/fakes.dart';

/// Categorías según `Category` de `catalog.v1.yaml`.
const _categorias = [
  {'id': 'c-plomeria', 'name': 'Plomería', 'description': 'Fugas y tuberías'},
  {'id': 'c-electrico', 'name': 'Eléctrico'},
];

void main() {
  late AlmacenSeguroEnMemoria memoria;
  late List<RequestOptions> peticiones;
  late ResponseBody Function() respuestaCategorias;

  setUp(() {
    memoria = AlmacenSeguroEnMemoria();
    peticiones = [];
    respuestaCategorias = () => respuestaJson(_categorias, 200);
  });

  Future<void> abrir(
    WidgetTester tester, {
    RolUsuario rol = RolUsuario.cliente,
    String? verificacion,
  }) async {
    // Teléfono de 400 x 1200 px lógicos: todo el inicio cabe sin desplazar.
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await AlmacenSesion(memoria).guardar(
      Sesion(
        accessToken: 'token-acceso',
        refreshToken: 'token-renovacion',
        expiraEn: DateTime.now().toUtc().add(const Duration(hours: 1)),
        usuario: UsuarioSesion(
          userId: 'u-1',
          fullName: 'Ana Gómez',
          rol: rol,
          verificationStatus: verificacion,
        ),
      ),
    );
    final container = ProviderContainer(
      overrides: [almacenSeguroProvider.overrideWithValue(memoria)],
    );
    addTearDown(container.dispose);
    container.read(clienteApiProvider).httpClientAdapter = AdaptadorFalso((o) {
      peticiones.add(o);
      return respuestaCategorias();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QuickpatchApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Pestaña de la barra inferior (el inicio puede repetir el texto).
  Finder pestana(String etiqueta) => find.descendant(
    of: find.byKey(const Key('barra-navegacion')),
    matching: find.text(etiqueta),
  );

  bool consultoCategorias() =>
      peticiones.any((o) => o.path == '/v1/catalog/categories');

  group('cliente', () {
    testWidgets('ve las categorías de Catalog y su barra de navegación', (
      tester,
    ) async {
      await abrir(tester);

      expect(find.text('Hola, Ana Gómez'), findsOneWidget);
      expect(find.text('¿Qué necesitas arreglar hoy?'), findsOneWidget);
      expect(consultoCategorias(), isTrue);
      expect(find.text('Plomería'), findsOneWidget);
      expect(find.text('Eléctrico'), findsOneWidget);
      expect(find.byKey(const Key('barra-navegacion')), findsOneWidget);
      for (final pestana in ['Inicio', 'Solicitudes', 'Cuenta']) {
        expect(find.text(pestana), findsOneWidget);
      }
      // "Nueva solicitud" no se repite en "Más opciones".
      expect(find.text('Nueva solicitud'), findsOneWidget);
      expect(find.text('Mis solicitudes'), findsOneWidget);
    });

    testWidgets('con texto al 200 % el inicio no se desborda (AC4-E7)', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await abrir(tester);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Eléctrico'), 200);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tocar una categoría abre la solicitud con ella elegida', (
      tester,
    ) async {
      await abrir(tester);
      await tester.tap(find.byKey(const Key('categoria-c-electrico')));
      await tester.pumpAndSettle();

      final pagina = tester.widget<NuevaSolicitudPage>(
        find.byType(NuevaSolicitudPage),
      );
      expect(pagina.categoriaInicial, 'c-electrico');
      expect(
        find.descendant(
          of: find.byKey(const Key('campo-categoria')),
          matching: find.text('Eléctrico'),
        ),
        findsOneWidget,
      );
      // La solicitud se abre encima de las pestañas, sin la barra.
      expect(find.byKey(const Key('barra-navegacion')), findsNothing);
    });

    testWidgets('el botón de la tarjeta abre la solicitud sin categoría', (
      tester,
    ) async {
      await abrir(tester);
      await tester.tap(find.byKey(const Key('boton-nueva-solicitud')));
      await tester.pumpAndSettle();

      final pagina = tester.widget<NuevaSolicitudPage>(
        find.byType(NuevaSolicitudPage),
      );
      expect(pagina.categoriaInicial, isNull);
    });

    testWidgets('muestra el error de Catalog y reintenta', (tester) async {
      respuestaCategorias = () => respuestaJson({'status': 503}, 503);
      await abrir(tester);
      expect(find.byKey(const Key('categorias-error')), findsOneWidget);

      respuestaCategorias = () => respuestaJson(_categorias, 200);
      await tester.ensureVisible(find.text('Reintentar'));
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('categorias-error')), findsNothing);
      expect(find.text('Plomería'), findsOneWidget);
    });

    testWidgets('sin categorías muestra el estado vacío', (tester) async {
      respuestaCategorias = () => respuestaJson(<Object>[], 200);
      await abrir(tester);
      expect(find.byKey(const Key('categorias-vacio')), findsOneWidget);
    });

    testWidgets('la pestaña Solicitudes explica lo pendiente y deja crear', (
      tester,
    ) async {
      await abrir(tester);
      await tester.tap(pestana('Solicitudes'));
      await tester.pumpAndSettle();

      expect(find.byType(ActividadPage), findsOneWidget);
      expect(find.textContaining('RF-11'), findsOneWidget);
      await tester.tap(find.text('Crear una solicitud'));
      await tester.pumpAndSettle();
      expect(find.byType(NuevaSolicitudPage), findsOneWidget);
    });

    testWidgets('la cuenta muestra iniciales, rol y licencias', (tester) async {
      await abrir(tester);
      await tester.tap(pestana('Cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('AG'), findsOneWidget);
      expect(find.text('Cliente'), findsOneWidget);
      await tester.tap(find.text('Licencias de software'));
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
    });
  });

  testWidgets('técnico en verificación ve el aviso, sus opciones y Ofertas', (
    tester,
  ) async {
    await abrir(tester, rol: RolUsuario.tecnico, verificacion: 'pendiente');

    expect(find.byKey(const Key('aviso-verificacion')), findsOneWidget);
    expect(find.text('Tu trabajo en QUICKPATCH'), findsOneWidget);
    expect(find.text('Disponibilidad y cobertura'), findsOneWidget);
    expect(consultoCategorias(), isFalse);
    expect(find.byKey(const Key('boton-nueva-solicitud')), findsNothing);

    await tester.tap(pestana('Ofertas'));
    await tester.pumpAndSettle();
    expect(find.textContaining('RF-10'), findsOneWidget);
    expect(find.text('Crear una solicitud'), findsNothing);
  });

  testWidgets('técnico aprobado no ve el aviso de verificación', (
    tester,
  ) async {
    await abrir(tester, rol: RolUsuario.tecnico, verificacion: 'aprobado');
    expect(find.byKey(const Key('aviso-verificacion')), findsNothing);
  });

  testWidgets('proveedor tiene la pestaña Equipo', (tester) async {
    await abrir(tester, rol: RolUsuario.proveedor);
    expect(find.text('Tu equipo en QUICKPATCH'), findsOneWidget);
    await tester.tap(pestana('Equipo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('RF-16'), findsOneWidget);
  });

  testWidgets('empresa cliente ve Solicitudes pero aún no solicita', (
    tester,
  ) async {
    await abrir(tester, rol: RolUsuario.empresaContacto);
    expect(find.text('Bienvenido a QUICKPATCH'), findsOneWidget);
    expect(find.text('Solicitudes'), findsOneWidget);
    expect(consultoCategorias(), isFalse);
  });

  testWidgets('la administración no tiene barra de navegación', (tester) async {
    await abrir(tester, rol: RolUsuario.adminPlataforma);
    expect(find.byKey(const Key('mensaje-admin')), findsOneWidget);
    expect(find.byKey(const Key('barra-navegacion')), findsNothing);
  });
}
