import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quickpatch_mobile/app/router/rutas.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';
import 'package:quickpatch_mobile/core/session/sesion.dart';
import 'package:quickpatch_mobile/features/cuenta/data/repositorio_perfil.dart';
import 'package:quickpatch_mobile/features/cuenta/domain/perfil.dart';
import 'package:quickpatch_mobile/features/cuenta/presentation/paginas/cuenta_page.dart';
import 'package:quickpatch_mobile/features/cuenta/presentation/paginas/editar_perfil_page.dart';

import '../../helpers/fakes.dart';

/// Edición del perfil propio (SCRUM-612; identity 1.9.0,
/// `GET` y `PATCH /v1/users/me`).
Map<String, dynamic> _perfil({
  String nombre = 'Pedro Ruiz',
  String? telefono = '3001234567',
}) => {
  'id': 'u-1',
  'email': 'pedro@correo.co',
  'fullName': nombre,
  'role': 'proveedor',
  'phone': telefono,
  'verificationStatus': 'aprobado',
  'companyId': null,
};

void main() {
  late AlmacenSeguroEnMemoria memoria;
  late List<RequestOptions> peticiones;
  late ResponseBody Function() alObtener;
  late ResponseBody Function(RequestOptions) alActualizar;

  setUp(() {
    memoria = AlmacenSeguroEnMemoria();
    peticiones = [];
    alObtener = () => respuestaJson(_perfil(), 200);
    alActualizar = (o) {
      final datos = o.data as Map<String, dynamic>;
      return respuestaJson(
        _perfil(
          nombre: datos['fullName'] as String? ?? 'Pedro Ruiz',
          telefono: datos.containsKey('phone')
              ? datos['phone'] as String?
              : '3001234567',
        ),
        200,
      );
    };
  });

  Finder clave(String k) => find.byKey(Key(k));

  List<RequestOptions> patches() =>
      peticiones.where((p) => p.method == 'PATCH').toList();

  /// Abre Cuenta (proveedor: sin buzón) y, si [editar], la edición.
  Future<void> abrir(WidgetTester tester, {bool editar = true}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await AlmacenSesion(memoria).guardar(
      Sesion(
        accessToken: 'token-acceso',
        expiraEn: DateTime.now().toUtc().add(const Duration(hours: 1)),
        usuario: const UsuarioSesion(
          userId: 'u-1',
          fullName: 'Pedro Ruiz',
          rol: RolUsuario.proveedor,
          verificationStatus: 'aprobado',
        ),
      ),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://qa.quickpatch.internal/api'))
      ..httpClientAdapter = AdaptadorFalso((o) {
        peticiones.add(o);
        return o.method == 'PATCH' ? alActualizar(o) : alObtener();
      });
    final router = GoRouter(
      initialLocation: Rutas.cuenta,
      routes: [
        GoRoute(
          path: Rutas.cuenta,
          builder: (context, state) => const CuentaPage(),
        ),
        GoRoute(
          path: Rutas.editarPerfil,
          builder: (context, state) => const EditarPerfilPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          almacenSeguroProvider.overrideWithValue(memoria),
          repositorioPerfilProvider.overrideWithValue(RepositorioPerfil(dio)),
        ],
        child: MaterialApp.router(
          theme: AppTheme.claro(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (editar) {
      await tester.tap(clave('fila-editar-perfil'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('muestra el perfil con el correo y el rol sin editar', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.text('Editar perfil'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('pedro@correo.co'), findsOneWidget);
    expect(find.text('Proveedor'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(2));
    expect(find.widgetWithText(TextFormField, 'Pedro Ruiz'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '3001234567'), findsOneWidget);
    // Sin cambios, el botón está deshabilitado.
    final boton = tester.widget<FilledButton>(
      find.descendant(
        of: clave('boton-guardar'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(boton.onPressed, isNull);
    expect(peticiones.single.path, '/v1/users/me');
    expect(peticiones.single.method, 'GET');
  });

  testWidgets('muestra la carga mientras llega el perfil', (tester) async {
    await abrir(tester, editar: false);
    await tester.tap(clave('fila-editar-perfil'));
    await tester.pump();
    await tester.pump();

    expect(find.bySemanticsLabel('Cargando tu perfil'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('si no carga, ofrece reintentar', (tester) async {
    alObtener = () => respuestaJson({
      'type': 'https://quickpatch.internal/problems/servicio-no-disponible',
      'title': 'No disponible',
      'status': 503,
    }, 503);
    await abrir(tester);

    expect(clave('error-perfil'), findsOneWidget);
    expect(find.text('No pudimos cargar tu perfil.'), findsOneWidget);

    alObtener = () => respuestaJson(_perfil(), 200);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(clave('error-perfil'), findsNothing);
    expect(find.text('pedro@correo.co'), findsOneWidget);
  });

  testWidgets('valida el nombre y el teléfono antes de enviar', (tester) async {
    await abrir(tester);

    await tester.enterText(clave('campo-nombre'), 'P');
    await tester.enterText(clave('campo-telefono'), '123');
    await tester.tap(clave('boton-guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Mínimo 2 caracteres.'), findsOneWidget);
    expect(find.text('Mínimo 7 caracteres.'), findsOneWidget);
    expect(patches(), isEmpty);
  });

  testWidgets('guarda solo el nombre y lo muestra en Cuenta', (tester) async {
    await abrir(tester);

    await tester.enterText(clave('campo-nombre'), '  Pedro Ruiz Gómez ');
    await tester.pump();
    await tester.tap(clave('boton-guardar'));
    await tester.pumpAndSettle();

    final patch = patches().single;
    expect(patch.path, '/v1/users/me');
    expect(patch.data, {'fullName': 'Pedro Ruiz Gómez'});
    // De vuelta en Cuenta, con el nombre nuevo y sin volver a iniciar sesión.
    expect(find.text('Editar perfil'), findsOneWidget); // la fila de Cuenta
    expect(find.byType(EditarPerfilPage), findsNothing);
    expect(find.text('Pedro Ruiz Gómez'), findsOneWidget);
    expect(find.text('Perfil actualizado.'), findsOneWidget);
    final guardada = await AlmacenSesion(memoria).cargar();
    expect(guardada!.usuario.fullName, 'Pedro Ruiz Gómez');
    expect(guardada.usuario.rol, RolUsuario.proveedor);
    expect(guardada.usuario.verificationStatus, 'aprobado');
  });

  testWidgets('borrar el teléfono envía phone en null', (tester) async {
    await abrir(tester);

    await tester.enterText(clave('campo-telefono'), '');
    await tester.pump();
    await tester.tap(clave('boton-guardar'));
    await tester.pumpAndSettle();

    expect(patches().single.data, {'phone': null});
  });

  testWidgets('muestra los errores del 400 en su campo', (tester) async {
    alActualizar = (_) => respuestaJson({
      'type': 'https://quickpatch.internal/problems/validacion',
      'title': 'Datos inválidos',
      'status': 400,
      'code': 'VALIDATION_ERROR',
      'errors': {
        'fullName': ['El nombre no es válido.'],
        'phone': ['El teléfono no es válido.'],
      },
    }, 400);
    await abrir(tester);

    await tester.enterText(clave('campo-nombre'), 'Pedro R.');
    await tester.enterText(clave('campo-telefono'), '3009999999');
    await tester.pump();
    await tester.tap(clave('boton-guardar'));
    await tester.pumpAndSettle();

    expect(find.text('El nombre no es válido.'), findsOneWidget);
    expect(find.text('El teléfono no es válido.'), findsOneWidget);
    expect(clave('mensaje-error'), findsNothing);
    // Sigue en la edición con lo que escribió.
    expect(find.byType(EditarPerfilPage), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Pedro R.'), findsOneWidget);
  });

  testWidgets('un error sin campos se muestra debajo del formulario', (
    tester,
  ) async {
    alActualizar = (_) => respuestaJson({
      'type': 'https://quickpatch.internal/problems/servicio-no-disponible',
      'title': 'No disponible',
      'status': 503,
    }, 503);
    await abrir(tester);

    await tester.enterText(clave('campo-nombre'), 'Pedro Ruiz G.');
    await tester.pump();
    await tester.tap(clave('boton-guardar'));
    await tester.pumpAndSettle();

    expect(clave('mensaje-error'), findsOneWidget);
    expect(find.byType(EditarPerfilPage), findsOneWidget);
  });

  testWidgets('salir con cambios pide confirmación', (tester) async {
    await abrir(tester);

    await tester.enterText(clave('campo-nombre'), 'Otro nombre');
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('¿Salir sin guardar?'), findsOneWidget);
    await tester.tap(clave('seguir-aqui'));
    await tester.pumpAndSettle();
    expect(find.byType(EditarPerfilPage), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Otro nombre'), findsOneWidget);

    // El botón atrás de Android también pregunta.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('¿Salir sin guardar?'), findsOneWidget);
    await tester.tap(clave('confirmar-salir'));
    await tester.pumpAndSettle();

    expect(find.byType(EditarPerfilPage), findsNothing);
    expect(find.text('Pedro Ruiz'), findsOneWidget);
    expect(patches(), isEmpty);
  });

  testWidgets('salir sin cambios no pregunta', (tester) async {
    await abrir(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('¿Salir sin guardar?'), findsNothing);
    expect(find.byType(EditarPerfilPage), findsNothing);
  });

  group('CambiosPerfil', () {
    const actual = Perfil(
      id: 'u-1',
      email: 'pedro@correo.co',
      nombreCompleto: 'Pedro Ruiz',
      rol: RolUsuario.proveedor,
      telefono: '3001234567',
    );

    test('sin cambios queda vacío', () {
      final c = CambiosPerfil.entre(
        actual,
        nombreCompleto: ' Pedro Ruiz ',
        telefono: '3001234567',
      );
      expect(c.vacio, isTrue);
      expect(c.toJson(), isEmpty);
    });

    test('nunca envía id, correo, rol ni tenant', () {
      final c = CambiosPerfil.entre(
        actual,
        nombreCompleto: 'Pedro',
        telefono: '3110000000',
      );
      expect(c.toJson(), {'fullName': 'Pedro', 'phone': '3110000000'});
    });

    test('un teléfono vacío sin teléfono guardado no es un cambio', () {
      const sinTelefono = Perfil(
        id: 'u-1',
        email: 'pedro@correo.co',
        nombreCompleto: 'Pedro Ruiz',
        rol: RolUsuario.proveedor,
      );
      final c = CambiosPerfil.entre(
        sinTelefono,
        nombreCompleto: 'Pedro Ruiz',
        telefono: '  ',
      );
      expect(c.vacio, isTrue);
    });

    test('Perfil rechaza un rol desconocido', () {
      expect(
        () => Perfil.desdeJson({..._perfil(), 'role': 'otro'}),
        throwsFormatException,
      );
    });
  });
}
