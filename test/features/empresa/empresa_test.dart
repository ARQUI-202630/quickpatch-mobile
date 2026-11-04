import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quickpatch_mobile/app/router/rutas.dart';
import 'package:quickpatch_mobile/app/shell/opciones_por_rol.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/core/compartir/compartir.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';
import 'package:quickpatch_mobile/features/empresa/data/repositorio_empresa.dart';
import 'package:quickpatch_mobile/features/empresa/presentation/paginas/agregar_usuario_empresa_page.dart';
import 'package:quickpatch_mobile/features/empresa/presentation/paginas/usuarios_empresa_page.dart';

import '../../helpers/fakes.dart';

/// Usuarios de la empresa cliente (RF-06, SCRUM-67; identity 1.8.0).
Map<String, dynamic> _usuario(String id, {bool activo = true}) => {
  'userId': id,
  'email': '$id@andinas.com.co',
  'fullName': 'Usuario $id',
  'phone': null,
  'passwordDefined': activo,
  'createdAt': '2026-10-21T15:00:00Z',
};

Map<String, dynamic> _invitacion() => {
  'link': 'https://quickpatch.internal/activar#token=abc',
  'token': 'abc',
  'expiresAt': '2026-10-24T15:00:00Z',
};

ResponseBody _problema(int status, String tipo) => respuestaJson({
  'type': 'https://quickpatch.internal/problems/$tipo',
  'title': tipo,
  'status': status,
}, status);

void main() {
  late List<RequestOptions> peticiones;
  late List<Map<String, dynamic>> usuarios;
  late ResponseBody Function(RequestOptions) alAgregar;
  late ResponseBody Function(RequestOptions) alRenovar;
  late ResponseBody Function() alListar;
  late List<String> compartidos;

  setUp(() {
    peticiones = [];
    compartidos = [];
    usuarios = [_usuario('u-1'), _usuario('u-2', activo: false)];
    alListar = () => respuestaJson({
      'items': usuarios,
      'page': 1,
      'size': 20,
      'totalItems': usuarios.length,
    }, 200);
    alAgregar = (o) {
      final datos = o.data as Map<String, dynamic>;
      usuarios = [...usuarios, _usuario('u-3', activo: false)];
      return respuestaJson({
        'id': 'u-3',
        'email': datos['email'],
        'fullName': datos['fullName'],
        'role': 'empresa_contacto',
        'companyId': 'c-1',
        'invitation': _invitacion(),
      }, 201);
    };
    alRenovar = (_) => respuestaJson(_invitacion(), 201);
  });

  Finder clave(String k) => find.byKey(Key(k));

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dio = Dio(BaseOptions(baseUrl: 'https://qa.quickpatch.internal/api'))
      ..httpClientAdapter = AdaptadorFalso((o) {
        peticiones.add(o);
        if (o.path == '/v1/companies/me') {
          return respuestaJson({
            'id': 'c-1',
            'legalName': 'Inversiones Andinas S.A.S.',
            'nit': '900123456-7',
            'contactEmail': 'compras@andinas.com.co',
            'contactPhone': null,
            'createdAt': '2026-10-21T15:00:00Z',
          }, 200);
        }
        if (o.path.endsWith('/invitation')) return alRenovar(o);
        return o.method == 'POST' ? alAgregar(o) : alListar();
      });
    final router = GoRouter(
      initialLocation: Rutas.usuariosEmpresa,
      routes: [
        GoRoute(
          path: Rutas.usuariosEmpresa,
          builder: (context, state) => const UsuariosEmpresaPage(),
        ),
        GoRoute(
          path: Rutas.agregarUsuarioEmpresa,
          builder: (context, state) => const AgregarUsuarioEmpresaPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          repositorioEmpresaProvider.overrideWithValue(RepositorioEmpresa(dio)),
          compartirProvider.overrideWithValue(({
            required String texto,
            String? asunto,
          }) async {
            compartidos.add(texto);
          }),
        ],
        child: MaterialApp.router(
          theme: AppTheme.claro(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  int listados() => peticiones
      .where((p) => p.path == '/v1/companies/me/users' && p.method == 'GET')
      .length;

  testWidgets('muestra la empresa y sus usuarios activos y pendientes', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.text('Inversiones Andinas S.A.S.'), findsOneWidget);
    expect(find.textContaining('NIT 900123456-7'), findsOneWidget);
    expect(find.text('2 usuarios'), findsOneWidget);
    expect(clave('estado-activo'), findsOneWidget);
    expect(clave('estado-pendiente'), findsOneWidget);
    // Solo el pendiente tiene enlace nuevo.
    expect(clave('enlace-u-1'), findsNothing);
    expect(clave('enlace-u-2'), findsOneWidget);
    final listado = peticiones.firstWhere(
      (p) => p.path == '/v1/companies/me/users',
    );
    expect(listado.queryParameters, {'page': 1, 'size': 20});
  });

  testWidgets('genera un enlace nuevo y lo comparte como de la empresa', (
    tester,
  ) async {
    await abrir(tester);

    await tester.tap(clave('enlace-u-2'));
    await tester.pumpAndSettle();
    await tester.tap(clave('confirmar-enlace-nuevo'));
    await tester.pumpAndSettle();

    expect(peticiones.last.path, '/v1/companies/me/users/u-2/invitation');
    expect(clave('enlace-invitacion'), findsOneWidget);
    expect(find.textContaining('los usuarios de tu empresa'), findsOneWidget);
    await tester.tap(clave('boton-compartir-enlace'));
    await tester.pumpAndSettle();
    expect(compartidos.single, contains('te agregué a mi empresa'));
    expect(compartidos.single, contains('#token=abc'));
  });

  testWidgets('si el usuario ya activó su cuenta, avisa y recarga', (
    tester,
  ) async {
    alRenovar = (_) => _problema(409, 'contrasena-definida');
    await abrir(tester);

    await tester.tap(clave('enlace-u-2'));
    await tester.pumpAndSettle();
    await tester.tap(clave('confirmar-enlace-nuevo'));
    await tester.pumpAndSettle();

    expect(find.text('Usuario u-2 ya activó su cuenta.'), findsOneWidget);
    expect(listados(), 2);
  });

  testWidgets('agrega un usuario, muestra su invitación y recarga la lista', (
    tester,
  ) async {
    await abrir(tester);

    await tester.tap(clave('boton-agregar-usuario'));
    await tester.pumpAndSettle();
    await tester.tap(clave('boton-agregar'));
    await tester.pumpAndSettle();
    expect(peticiones.where((p) => p.method == 'POST'), isEmpty);

    await tester.enterText(clave('campo-nombre'), 'Andrés Peña');
    await tester.enterText(clave('campo-email'), ' andres@andinas.com.co ');
    await tester.tap(clave('boton-agregar'));
    await tester.pumpAndSettle();

    final alta = peticiones.lastWhere((p) => p.method == 'POST');
    expect(alta.path, '/v1/companies/me/users');
    expect(alta.data, {
      'email': 'andres@andinas.com.co',
      'fullName': 'Andrés Peña',
    });
    expect(
      find.textContaining('ya puede pedir servicios a nombre de tu empresa'),
      findsOneWidget,
    );

    await tester.tap(clave('boton-cerrar-invitacion'));
    await tester.pumpAndSettle();
    expect(find.text('3 usuarios'), findsOneWidget);
    expect(listados(), 2);
  });

  testWidgets('correo repetido se muestra junto al campo', (tester) async {
    alAgregar = (_) => _problema(409, 'correo-registrado');
    await abrir(tester);
    await tester.tap(clave('boton-agregar-usuario'));
    await tester.pumpAndSettle();

    await tester.enterText(clave('campo-nombre'), 'Andrés Peña');
    await tester.enterText(clave('campo-email'), 'u-1@andinas.com.co');
    await tester.tap(clave('boton-agregar'));
    await tester.pumpAndSettle();

    expect(find.text('Ya hay una cuenta con este correo.'), findsOneWidget);
    expect(clave('mensaje-error'), findsNothing);
  });

  testWidgets('otro error del alta se muestra debajo del formulario', (
    tester,
  ) async {
    alAgregar = (_) => _problema(503, 'servicio-no-disponible');
    await abrir(tester);
    await tester.tap(clave('boton-agregar-usuario'));
    await tester.pumpAndSettle();

    await tester.enterText(clave('campo-nombre'), 'Andrés Peña');
    await tester.enterText(clave('campo-email'), 'andres@andinas.com.co');
    await tester.tap(clave('boton-agregar'));
    await tester.pumpAndSettle();

    expect(clave('mensaje-error'), findsOneWidget);
  });

  testWidgets('si la lista no carga, permite reintentar', (tester) async {
    alListar = () => _problema(503, 'servicio-no-disponible');
    await abrir(tester);

    expect(clave('error-usuarios-empresa'), findsOneWidget);
    expect(clave('boton-agregar-usuario'), findsNothing);

    alListar = () => respuestaJson({
      'items': [_usuario('u-1')],
      'page': 1,
      'size': 20,
      'totalItems': 1,
    }, 200);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('1 usuario'), findsOneWidget);
  });

  testWidgets('carga más usuarios por páginas', (tester) async {
    var pagina = 0;
    alListar = () {
      pagina++;
      return respuestaJson({
        'items': [_usuario('p$pagina')],
        'page': pagina,
        'size': 20,
        'totalItems': 2,
      }, 200);
    };
    await abrir(tester);

    await tester.tap(clave('boton-cargar-mas'));
    await tester.pumpAndSettle();

    expect(peticiones.last.queryParameters, {'page': 2, 'size': 20});
    expect(find.text('Usuario p2'), findsOneWidget);
    expect(clave('boton-cargar-mas'), findsNothing);
  });

  test('el empresa_contacto tiene la opción de sus usuarios', () {
    final opcion = opcionesPara(RolUsuario.empresaContacto)
        .singleWhere((o) => o.requisito == 'RF-06');
    expect(opcion.ruta, Rutas.usuariosEmpresa);
  });
}
