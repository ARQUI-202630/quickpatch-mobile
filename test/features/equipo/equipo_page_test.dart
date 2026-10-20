import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/app.dart';
import 'package:quickpatch_mobile/app/router/app_router.dart';
import 'package:quickpatch_mobile/app/router/rutas.dart';
import 'package:quickpatch_mobile/core/network/cliente_api.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';
import 'package:quickpatch_mobile/features/equipo/data/compartir.dart';

import '../../helpers/fakes.dart';

/// SCRUM-98: equipo del proveedor con el enlace de invitación (identity 1.7.0).
void main() {
  const enlace =
      'https://quickpatch.internal/activar#token=abcdefghijklmnopqrstuvwxyzABCDEFGHIJ012-_56';
  const categorias = [
    {'id': 'c-1', 'name': 'Plomería'},
    {'id': 'c-2', 'name': 'Electricidad'},
  ];

  late List<RequestOptions> peticiones;
  late List<Map<String, dynamic>> equipo;
  late ResponseBody Function()? respuestaLista;
  late ResponseBody Function()? respuestaAlta;
  late ResponseBody Function()? respuestaInvitacion;
  late String? copiado;
  late List<(String, String?)> compartidos;

  Map<String, dynamic> tecnico(
    String id,
    String nombre, {
    String especialidad = 'c-1',
    String verificacion = 'pendiente',
  }) => {
    'userId': id,
    'fullName': nombre,
    'specialtyId': especialidad,
    'verificationStatus': verificacion,
  };

  Map<String, dynamic> invitacion() => {
    'link': enlace,
    'token': enlace.split('=').last,
    'expiresAt': '2026-10-17T20:02:00Z',
  };

  setUp(() {
    peticiones = [];
    equipo = [];
    respuestaLista = null;
    respuestaAlta = null;
    respuestaInvitacion = null;
    copiado = null;
    compartidos = [];
  });

  /// Responde como Identity: filtra por `status` y pagina por `page`/`size`.
  ResponseBody listar(RequestOptions o) {
    final status = o.queryParameters['status'] as String?;
    final pagina = o.queryParameters['page'] as int;
    final tamano = o.queryParameters['size'] as int;
    final filtrados = equipo.where(
      (t) =>
          status == null ||
          (status == 'activo') == (t['verificationStatus'] == 'aprobado'),
    );
    return respuestaJson({
      'items': filtrados.skip((pagina - 1) * tamano).take(tamano).toList(),
      'page': pagina,
      'size': tamano,
      'totalItems': filtrados.length,
    }, 200);
  }

  AdaptadorFalso adaptador() => AdaptadorFalso((o) {
    peticiones.add(o);
    final ruta = o.path;
    if (ruta.endsWith('/v1/service-requests/categories')) {
      return respuestaJson(categorias, 200);
    }
    if (ruta.endsWith('/invitation')) {
      return respuestaInvitacion?.call() ?? respuestaJson(invitacion(), 201);
    }
    if (ruta.endsWith('/v1/providers/me/technicians')) {
      if (o.method == 'POST') {
        final r = respuestaAlta?.call();
        if (r != null) return r;
        final datos = o.data as Map<String, dynamic>;
        equipo.add(
          tecnico(
            'nuevo',
            datos['fullName'] as String,
            especialidad: datos['specialtyId'] as String,
          ),
        );
        return respuestaJson({
          'id': 'nuevo',
          'email': datos['email'],
          'fullName': datos['fullName'],
          'role': 'tecnico',
          'phone': datos['phone'],
          'verificationStatus': 'pendiente',
          'invitation': invitacion(),
        }, 201);
      }
      return respuestaLista?.call() ?? listar(o);
    }
    return respuestaJson(<String, dynamic>{}, 404);
  });

  Future<void> abrir(
    WidgetTester tester, {
    double escalaTexto = 1,
    Brightness brillo = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = escalaTexto;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = brillo;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
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

    final memoria = AlmacenSeguroEnMemoria();
    await AlmacenSesion(memoria)
        .guardar(sesionDePrueba(rol: RolUsuario.proveedor));
    final container = ProviderContainer(
      overrides: [
        almacenSeguroProvider.overrideWithValue(memoria),
        compartirProvider.overrideWithValue(({
          required String texto,
          String? asunto,
        }) async {
          compartidos.add((texto, asunto));
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(clienteApiProvider).httpClientAdapter = adaptador();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QuickpatchApp(),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      Future<void>(() => container.read(routerProvider).go(Rutas.actividad)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tocar(WidgetTester tester, Finder objetivo) async {
    await tester.ensureVisible(objetivo);
    await tester.tap(objetivo);
    await tester.pumpAndSettle();
  }

  Iterable<RequestOptions> listados() => peticiones.where(
    (p) => p.method == 'GET' && p.path.endsWith('/v1/providers/me/technicians'),
  );

  Iterable<RequestOptions> posts(String final_) =>
      peticiones.where((p) => p.method == 'POST' && p.path.endsWith(final_));

  group('lista', () {
    testWidgets('muestra el equipo con especialidad y verificación', (
      tester,
    ) async {
      equipo = [
        tecnico('t1', 'Carlos Ruiz'),
        tecnico(
          't2',
          'Ana Gómez',
          especialidad: 'c-2',
          verificacion: 'aprobado',
        ),
        tecnico(
          't3',
          'Luis Mora',
          especialidad: 'c-9',
          verificacion: 'suspendido',
        ),
      ];
      await abrir(tester);

      expect(find.text('Equipo'), findsWidgets);
      expect(find.text('Carlos Ruiz'), findsOneWidget);
      expect(find.text('Plomería'), findsOneWidget);
      expect(find.text('Electricidad'), findsOneWidget);
      // Especialidad que ya no está en el catálogo.
      expect(find.text('—'), findsOneWidget);
      expect(find.byKey(const Key('verificacion-pendiente')), findsOneWidget);
      expect(find.byKey(const Key('verificacion-aprobado')), findsOneWidget);
      expect(find.byKey(const Key('verificacion-suspendido')), findsOneWidget);
      expect(find.text('3 técnicos'), findsOneWidget);

      final primera = listados().first;
      expect(primera.queryParameters, {'page': 1, 'size': 20});
      expect(primera.headers['Authorization'], 'Bearer token-acceso');
      expect(primera.queryParameters.containsKey('tenantId'), isFalse);
    });

    testWidgets('filtra por activos e inactivos', (tester) async {
      equipo = [
        tecnico('t1', 'Carlos Ruiz'),
        tecnico('t2', 'Ana Gómez', verificacion: 'aprobado'),
      ];
      await abrir(tester);

      await tocar(tester, find.text('Activos'));
      expect(listados().last.queryParameters['status'], 'activo');
      expect(find.text('Ana Gómez'), findsOneWidget);
      expect(find.text('Carlos Ruiz'), findsNothing);
      expect(find.text('1 técnico'), findsOneWidget);

      await tocar(tester, find.text('Inactivos'));
      expect(listados().last.queryParameters['status'], 'inactivo');
      expect(find.text('Carlos Ruiz'), findsOneWidget);

      // Repetir el filtro actual no vuelve a consultar.
      final antes = listados().length;
      await tocar(tester, find.text('Inactivos'));
      expect(listados().length, antes);
    });

    testWidgets('un filtro sin técnicos lo dice', (tester) async {
      equipo = [tecnico('t1', 'Carlos Ruiz')];
      await abrir(tester);
      await tocar(tester, find.text('Activos'));
      expect(find.text('No hay técnicos activos.'), findsOneWidget);
    });

    testWidgets('pagina con «Cargar más»', (tester) async {
      equipo = [for (var i = 1; i <= 25; i++) tecnico('t$i', 'Técnico $i')];
      await abrir(tester);

      expect(find.text('25 técnicos'), findsOneWidget);
      final lista = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(
        find.text('Técnico 20'),
        300,
        scrollable: lista,
      );
      expect(find.text('Técnico 21'), findsNothing);

      await tester.scrollUntilVisible(
        find.byKey(const Key('boton-cargar-mas')),
        300,
        scrollable: lista,
      );
      await tocar(tester, find.byKey(const Key('boton-cargar-mas')));
      expect(listados().last.queryParameters['page'], 2);
      await tester.scrollUntilVisible(
        find.text('Técnico 25'),
        300,
        scrollable: lista,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('boton-cargar-mas')), findsNothing);
    });

    testWidgets('sin técnicos invita a agregar el primero', (tester) async {
      await abrir(tester);
      expect(find.byKey(const Key('equipo-vacio')), findsOneWidget);
      // Sin técnicos, el botón flotante no repite la acción del estado vacío.
      expect(find.byKey(const Key('boton-agregar-tecnico')), findsNothing);
      await tocar(tester, find.text('Agregar técnico'));
      expect(find.byKey(const Key('boton-guardar-tecnico')), findsOneWidget);
      expect(find.text('Nombre completo'), findsOneWidget);
    });

    testWidgets('si la lista falla permite reintentar', (tester) async {
      respuestaLista = () => respuestaJson({'status': 503}, 503);
      await abrir(tester);
      expect(find.byKey(const Key('error-equipo')), findsOneWidget);

      respuestaLista = null;
      equipo = [tecnico('t1', 'Carlos Ruiz')];
      await tocar(tester, find.text('Reintentar'));
      expect(find.text('Carlos Ruiz'), findsOneWidget);
    });
  });

  group('alta', () {
    Future<void> llenar(WidgetTester tester) async {
      await tester.enterText(
        find.byKey(const Key('campo-nombre')),
        ' Carlos Ruiz ',
      );
      await tester.enterText(
        find.byKey(const Key('campo-email')),
        'carlos@correo.co',
      );
      await tester.enterText(
        find.byKey(const Key('campo-telefono')),
        '3001234567',
      );
      await tester.enterText(
        find.byKey(const Key('campo-documento')),
        '1020304050',
      );
      await tester.pump();
      await tocar(tester, find.byKey(const Key('categoria-c-2')));
    }

    /// Con el equipo vacío se entra desde el estado vacío.
    Future<void> abrirAlta(WidgetTester tester) async {
      await abrir(tester);
      await tocar(tester, find.text('Agregar técnico'));
    }

    testWidgets('da de alta, muestra la invitación una sola vez y recarga', (
      tester,
    ) async {
      await abrirAlta(tester);
      await llenar(tester);
      await tocar(tester, find.byKey(const Key('boton-guardar-tecnico')));

      final alta = posts('/v1/providers/me/technicians').single;
      expect(alta.data, {
        'email': 'carlos@correo.co',
        'fullName': 'Carlos Ruiz',
        'phone': '3001234567',
        'documentId': '1020304050',
        'specialtyId': 'c-2',
      });
      expect((alta.data as Map).containsKey('password'), isFalse);

      // Hoja con el enlace, el vencimiento y el aviso de que solo se ve ahora.
      expect(find.text('Invitación de Carlos Ruiz'), findsOneWidget);
      expect(find.textContaining('quedó en tu equipo'), findsOneWidget);
      expect(find.text(enlace), findsOneWidget);
      expect(find.byKey(const Key('vence-invitacion')), findsOneWidget);
      expect(find.textContaining('solo se muestra ahora'), findsOneWidget);

      // Compartir abre el menú nativo con un mensaje listo para el técnico.
      await tocar(tester, find.byKey(const Key('boton-compartir-enlace')));
      final (texto, asunto) = compartidos.single;
      expect(asunto, 'Tu invitación a QUICKPATCH');
      expect(texto, startsWith('Hola Carlos Ruiz, te agregué a mi equipo'));
      expect(texto, contains('sirve una sola vez'));
      expect(texto, endsWith(enlace));

      await tocar(tester, find.byKey(const Key('boton-copiar-enlace')));
      expect(copiado, enlace);
      expect(find.text('Enlace copiado'), findsOneWidget);

      final antes = listados().length;
      await tocar(tester, find.byKey(const Key('boton-cerrar-invitacion')));
      expect(listados().length, antes + 1);
      expect(find.byKey(const Key('filtro-equipo')), findsOneWidget);
      expect(find.text('Carlos Ruiz'), findsOneWidget);
    });

    testWidgets('valida los campos antes de enviar', (tester) async {
      await abrirAlta(tester);
      await tocar(tester, find.byKey(const Key('boton-guardar-tecnico')));

      expect(find.text('Es obligatorio.'), findsNWidgets(3));
      expect(find.text('Elige su especialidad.'), findsOneWidget);
      expect(posts('/v1/providers/me/technicians'), isEmpty);
    });

    testWidgets('el correo repetido (409) queda junto a su campo', (
      tester,
    ) async {
      respuestaAlta = () => respuestaJson({
        'type': 'https://quickpatch.internal/problems/correo-registrado',
        'status': 409,
      }, 409);
      await abrirAlta(tester);
      await llenar(tester);
      await tocar(tester, find.byKey(const Key('boton-guardar-tecnico')));

      expect(find.text('Ya hay una cuenta con este correo.'), findsOneWidget);
      expect(find.byKey(const Key('mensaje-error')), findsNothing);
      expect(find.text('Invitación de Carlos Ruiz'), findsNothing);
    });

    testWidgets('el documento repetido y los 400 quedan en su campo', (
      tester,
    ) async {
      respuestaAlta = () => respuestaJson({
        'type': 'https://quickpatch.internal/problems/documento-registrado',
        'status': 409,
      }, 409);
      await abrirAlta(tester);
      await llenar(tester);
      await tocar(tester, find.byKey(const Key('boton-guardar-tecnico')));
      expect(
        find.text('Ya hay una cuenta con este documento.'),
        findsOneWidget,
      );

      respuestaAlta = () => respuestaJson({
        'type': 'https://quickpatch.internal/problems/validacion',
        'status': 400,
        'errors': {
          'phone': ['El teléfono no es válido.'],
          'specialtyId': ['La especialidad no existe.'],
        },
      }, 400);
      await tocar(tester, find.byKey(const Key('boton-guardar-tecnico')));
      expect(find.text('El teléfono no es válido.'), findsOneWidget);
      expect(find.text('La especialidad no existe.'), findsOneWidget);
    });

    testWidgets('un error sin campo se muestra como mensaje general', (
      tester,
    ) async {
      respuestaAlta = () => respuestaJson({
        'type': 'https://quickpatch.internal/problems/no-autorizado',
        'status': 403,
      }, 403);
      await abrirAlta(tester);
      await llenar(tester);
      await tocar(tester, find.byKey(const Key('boton-guardar-tecnico')));
      expect(find.byKey(const Key('mensaje-error')), findsOneWidget);
    });
  });

  group('enlace nuevo', () {
    Future<void> pedirEnlace(WidgetTester tester) async {
      equipo = [tecnico('t1', 'Carlos Ruiz')];
      await abrir(tester);
      await tocar(tester, find.byKey(const Key('menu-t1')));
      await tocar(tester, find.text('Generar enlace nuevo'));
    }

    testWidgets('pide confirmación y muestra el enlace nuevo', (tester) async {
      await pedirEnlace(tester);
      expect(
        find.text('¿Generar un enlace nuevo para Carlos Ruiz?'),
        findsOneWidget,
      );
      await tocar(tester, find.byKey(const Key('confirmar-enlace-nuevo')));

      expect(posts('/v1/providers/me/technicians/t1/invitation'), hasLength(1));
      expect(
        find.textContaining('Los anteriores ya no funcionan'),
        findsOneWidget,
      );
      expect(find.text(enlace), findsOneWidget);
    });

    testWidgets('cancelar no genera nada', (tester) async {
      await pedirEnlace(tester);
      await tocar(tester, find.text('Cancelar'));
      expect(posts('/invitation'), isEmpty);
    });

    testWidgets('si ya activó su cuenta lo avisa (409)', (tester) async {
      respuestaInvitacion = () => respuestaJson({
        'type': 'https://quickpatch.internal/problems/contrasena-definida',
        'status': 409,
      }, 409);
      await pedirEnlace(tester);
      await tocar(tester, find.byKey(const Key('confirmar-enlace-nuevo')));
      expect(find.textContaining('ya activó su cuenta'), findsOneWidget);
    });

    testWidgets('si ya no está en el equipo lo avisa y recarga (404)', (
      tester,
    ) async {
      respuestaInvitacion = () => respuestaJson({
        'type': 'https://quickpatch.internal/problems/no-encontrado',
        'status': 404,
      }, 404);
      await pedirEnlace(tester);
      final antes = listados().length;
      await tocar(tester, find.byKey(const Key('confirmar-enlace-nuevo')));
      expect(find.textContaining('ya no está en tu equipo'), findsOneWidget);
      expect(listados().length, antes + 1);
    });

    testWidgets('otro error se avisa sin perder la lista', (tester) async {
      respuestaInvitacion = () => ResponseBody.fromString('', 503);
      await pedirEnlace(tester);
      await tocar(tester, find.byKey(const Key('confirmar-enlace-nuevo')));
      expect(
        find.text('El servicio no está disponible. Intenta más tarde.'),
        findsOneWidget,
      );
      expect(find.text('Carlos Ruiz'), findsOneWidget);
    });
  });

  testWidgets('no se desborda con el texto al 200 % (AC4-E7)', (tester) async {
    equipo = [tecnico('t1', 'Carlos Ruiz Martínez de la Torre')];
    await abrir(tester, escalaTexto: 2);
    expect(tester.takeException(), isNull);
    await tocar(tester, find.byKey(const Key('boton-agregar-tecnico')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('funciona con el tema oscuro', (tester) async {
    equipo = [tecnico('t1', 'Carlos Ruiz', verificacion: 'rechazado')];
    await abrir(tester, brillo: Brightness.dark);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('verificacion-rechazado')), findsOneWidget);
  });
}
