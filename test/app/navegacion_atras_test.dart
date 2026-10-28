import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quickpatch_mobile/app/app.dart';
import 'package:quickpatch_mobile/app/router/app_router.dart';
import 'package:quickpatch_mobile/app/router/rutas.dart';
import 'package:quickpatch_mobile/core/network/cliente_api.dart';
import 'package:quickpatch_mobile/core/realtime/canal_tiempo_real.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/core/session/rol_usuario.dart';
import 'package:quickpatch_mobile/shared/widgets/vista_cargando.dart';

import '../helpers/fakes.dart';

/// Almacén que no responde hasta que la prueba lo libera.
class _AlmacenLento extends AlmacenSeguroEnMemoria {
  final _listo = Completer<void>();

  void liberar() => _listo.complete();

  @override
  Future<String?> leer(String clave) async {
    await _listo.future;
    return super.leer(clave);
  }
}

/// SCRUM-617 (historia SCRUM-615): flecha hacia atrás y botón atrás del
/// sistema en cada pantalla, según la regla de `docs/navegacion.md`.
///
/// Las pruebas recorren la app real con un servidor falso. Las pantallas que
/// no necesitan datos para mostrar su barra quedan en su estado de error, que
/// es suficiente: aquí solo importa a dónde lleva atrás.
void main() {
  late AlmacenSeguroEnMemoria memoria;
  late ConectorWsFalso conector;
  late int salidasDeLaApp;

  const localidades = [
    {'code': '01', 'name': 'Usaquén'},
    {'code': '02', 'name': 'Chapinero'},
  ];

  ResponseBody servidor(RequestOptions o) {
    final ruta = o.path;
    Map<String, dynamic> pagina() => {
      'items': <dynamic>[],
      'page': 1,
      'size': 20,
      'totalItems': 0,
    };
    if (ruta.endsWith('/messages')) {
      return respuestaJson({...pagina(), 'writable': true}, 200);
    }
    if (ruta.endsWith('/v1/service-requests/categories')) {
      return respuestaJson([
        {'id': 'c-1', 'name': 'Plomería'},
      ], 200);
    }
    if (ruta.endsWith('/v1/service-requests/localities')) {
      return respuestaJson(localidades, 200);
    }
    if (ruta.endsWith('/v1/technicians/me/availability')) {
      return respuestaJson({
        'status': 'no_disponible',
        'updatedAt': '2026-10-12T15:00:00Z',
      }, 200);
    }
    if (ruta.endsWith('/v1/technicians/me/coverage')) {
      return respuestaJson({
        'localities': [localidades[1]],
      }, 200);
    }
    if (ruta == '/v1/service-requests' ||
        ruta == '/v1/matching/offers' ||
        ruta == '/v1/providers/me/technicians' ||
        ruta == '/v1/technicians/me/service-requests' ||
        ruta == '/v1/companies/me/users') {
      return respuestaJson(pagina(), 200);
    }
    return respuestaJson({
      'type': 'https://quickpatch.internal/problems/no-encontrado',
      'title': 'no-encontrado',
      'status': 404,
    }, 404);
  }

  setUp(() {
    memoria = AlmacenSeguroEnMemoria();
    conector = ConectorWsFalso();
    salidasDeLaApp = 0;
  });

  /// Abre la app. Con [rol] hay sesión y se queda en Inicio; sin él, en el
  /// login. Devuelve el router para navegar como lo harían los botones.
  Future<GoRouter> abrir(WidgetTester tester, {RolUsuario? rol}) async {
    // Con la fuente de las pruebas (cada letra mide un em) un teléfono de 400 px
    // desborda el selector del tipo de documento de Pagar; las demás pruebas
    // de pantallas usan este mismo ancho.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // `SystemNavigator.pop` es lo que hace el sistema cuando nadie atiende el
    // botón atrás: la app se cierra.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (llamada) async {
        if (llamada.method == 'SystemNavigator.pop') salidasDeLaApp++;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    if (rol != null) {
      await AlmacenSesion(memoria).guardar(sesionDePrueba(rol: rol));
    }
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        almacenSeguroProvider.overrideWithValue(memoria),
        canalTiempoRealProvider.overrideWith((ref) {
          final canal = CanalTiempoReal(
            url: Uri.parse('ws://localhost/api/v1/realtime'),
            obtenerToken: () => 'token-acceso',
            conectar: conector.call,
          );
          ref.onDispose(canal.cerrar);
          return canal;
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(clienteApiProvider).httpClientAdapter = AdaptadorFalso(
      servidor,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QuickpatchApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container.read(routerProvider);
  }

  /// Ruta de la pantalla de arriba, apilada o no.
  String donde(GoRouter router) => router.state.uri.path;

  /// Abre la pantalla como lo hacen los botones de la app: apilándola.
  Future<void> apilar(WidgetTester tester, GoRouter router, String ruta) async {
    unawaited(router.push<Object?>(ruta));
    await tester.pumpAndSettle();
  }

  Future<void> atrasDelSistema(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  final flecha = find.descendant(
    of: find.byType(AppBar),
    matching: find.byType(BackButton),
  );

  Future<void> tocarFlecha(WidgetTester tester) async {
    await tester.tap(flecha);
    await tester.pumpAndSettle();
  }

  Finder clave(String k) => find.byKey(Key(k));

  group('pantallas raíz: sin flecha', () {
    testWidgets('Cargando es una pantalla de paso, sin barra', (tester) async {
      // La sesión tarda en leerse: mientras tanto la app está en Cargando.
      final lento = _AlmacenLento();
      await AlmacenSesion(lento).guardar(sesionDePrueba());
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [almacenSeguroProvider.overrideWithValue(lento)],
      );
      addTearDown(container.dispose);
      container.read(clienteApiProvider).httpClientAdapter = AdaptadorFalso(
        servidor,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const QuickpatchApp(),
        ),
      );
      await tester.pump();

      expect(donde(container.read(routerProvider)), Rutas.cargando);
      expect(find.byType(VistaCargando), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      lento.liberar();
      await tester.pumpAndSettle();
      expect(donde(container.read(routerProvider)), Rutas.inicio);
    });

    testWidgets('Iniciar sesión no tiene flecha y atrás sale de la app', (
      tester,
    ) async {
      final router = await abrir(tester);

      expect(donde(router), Rutas.iniciarSesion);
      expect(find.byType(AppBar), findsNothing);
      await atrasDelSistema(tester);
      expect(salidasDeLaApp, 1);
    });

    testWidgets('Inicio no tiene flecha y atrás sale de la app', (
      tester,
    ) async {
      final router = await abrir(tester, rol: RolUsuario.cliente);

      expect(donde(router), Rutas.inicio);
      expect(flecha, findsNothing);
      await atrasDelSistema(tester);
      expect(salidasDeLaApp, 1);
    });

    for (final (rol, nombre) in [
      (RolUsuario.cliente, 'Mis solicitudes'),
      (RolUsuario.tecnico, 'Servicios'),
      (RolUsuario.proveedor, 'Equipo'),
    ]) {
      testWidgets('Actividad de $rol ($nombre): atrás vuelve a Inicio', (
        tester,
      ) async {
        final router = await abrir(tester, rol: rol);
        router.go(Rutas.actividad);
        await tester.pumpAndSettle();

        expect(donde(router), Rutas.actividad);
        expect(flecha, findsNothing);
        await atrasDelSistema(tester);
        expect(donde(router), Rutas.inicio);
        expect(salidasDeLaApp, 0);
      });
    }

    testWidgets('Cuenta no tiene flecha y atrás vuelve a Inicio', (
      tester,
    ) async {
      final router = await abrir(tester, rol: RolUsuario.cliente);
      router.go(Rutas.cuenta);
      await tester.pumpAndSettle();

      expect(donde(router), Rutas.cuenta);
      expect(flecha, findsNothing);
      await atrasDelSistema(tester);
      expect(donde(router), Rutas.inicio);
      expect(salidasDeLaApp, 0);
    });
  });

  group('pantallas secundarias: la flecha y atrás vuelven a la anterior', () {
    // (nombre, rol, ruta). Todas se abren desde Inicio.
    final desdeInicio = <(String, RolUsuario, String)>[
      ('Notificaciones', RolUsuario.cliente, Rutas.notificaciones),
      ('Disponibilidad y cobertura', RolUsuario.tecnico, Rutas.disponibilidad),
      (
        'Usuarios de la empresa',
        RolUsuario.empresaContacto,
        Rutas.usuariosEmpresa,
      ),
      (
        'Agregar usuario de la empresa',
        RolUsuario.empresaContacto,
        Rutas.agregarUsuarioEmpresa,
      ),
      ('Agregar técnico', RolUsuario.proveedor, Rutas.altaTecnico),
      ('Nueva solicitud', RolUsuario.cliente, Rutas.nuevaSolicitud),
      ('Servicio asignado', RolUsuario.tecnico, Rutas.solicitudAsignada('s-1')),
      (
        'Detalle de la solicitud',
        RolUsuario.cliente,
        Rutas.detalleSolicitud('s-1'),
      ),
      ('Chat del servicio', RolUsuario.cliente, Rutas.chatSolicitud('s-1')),
      ('Pagar el servicio', RolUsuario.cliente, Rutas.pagarSolicitud('s-1')),
      ('Comprobante de pago', RolUsuario.cliente, Rutas.comprobante('p-1')),
    ];

    for (final (nombre, rol, ruta) in desdeInicio) {
      testWidgets('$nombre: flecha de la barra', (tester) async {
        final router = await abrir(tester, rol: rol);
        await apilar(tester, router, ruta);

        expect(donde(router), Uri.parse(ruta).path);
        expect(flecha, findsOneWidget);
        await tocarFlecha(tester);
        expect(donde(router), Rutas.inicio);
        expect(salidasDeLaApp, 0);
      });

      testWidgets('$nombre: botón atrás del sistema', (tester) async {
        final router = await abrir(tester, rol: rol);
        await apilar(tester, router, ruta);

        await atrasDelSistema(tester);
        expect(donde(router), Rutas.inicio);
        expect(salidasDeLaApp, 0);
      });
    }

    for (final (nombre, tecla, ruta) in [
      ('Registro de cliente', 'boton-ir-registro', Rutas.registro),
      (
        'Registro de técnico',
        'boton-ir-registro-tecnico',
        Rutas.registroTecnico,
      ),
    ]) {
      testWidgets('$nombre: se apila sobre el login y la flecha vuelve', (
        tester,
      ) async {
        final router = await abrir(tester);
        await tester.ensureVisible(clave(tecla));
        await tester.tap(clave(tecla));
        await tester.pumpAndSettle();

        expect(donde(router), ruta);
        expect(flecha, findsOneWidget);
        await tocarFlecha(tester);
        expect(donde(router), Rutas.iniciarSesion);
        expect(salidasDeLaApp, 0);
      });

      testWidgets('$nombre: atrás del sistema vuelve al login', (tester) async {
        final router = await abrir(tester);
        await tester.ensureVisible(clave(tecla));
        await tester.tap(clave(tecla));
        await tester.pumpAndSettle();

        await atrasDelSistema(tester);
        expect(donde(router), Rutas.iniciarSesion);
        expect(salidasDeLaApp, 0);
      });
    }

    testWidgets('Activar cuenta desde el login: la flecha vuelve al login', (
      tester,
    ) async {
      final router = await abrir(tester);
      await apilar(tester, router, Rutas.activarCuenta);

      expect(flecha, findsOneWidget);
      await tocarFlecha(tester);
      expect(donde(router), Rutas.iniciarSesion);
    });

    testWidgets(
      'Activar cuenta desde el enlace (sin pila): atrás va al login',
      (tester) async {
        final router = await abrir(tester);
        router.go(Rutas.activarCuenta);
        await tester.pumpAndSettle();

        expect(router.canPop(), isFalse);
        expect(flecha, findsOneWidget);
        await tocarFlecha(tester);
        expect(donde(router), Rutas.iniciarSesion);

        router.go(Rutas.activarCuenta);
        await tester.pumpAndSettle();
        await atrasDelSistema(tester);
        expect(donde(router), Rutas.iniciarSesion);
        expect(salidasDeLaApp, 0);
      },
    );
  });

  group('detalle de la solicitud del cliente', () {
    testWidgets('abierto desde la lista: la flecha vuelve a la lista', (
      tester,
    ) async {
      final router = await abrir(tester, rol: RolUsuario.cliente);
      router.go(Rutas.actividad);
      await tester.pumpAndSettle();
      await apilar(tester, router, Rutas.detalleSolicitud('s-1'));

      expect(find.byIcon(Icons.home_outlined), findsNothing);
      expect(flecha, findsOneWidget);
      await tocarFlecha(tester);
      expect(donde(router), Rutas.actividad);
    });

    testWidgets('recién creada (sin pila): la flecha lleva a Mis solicitudes', (
      tester,
    ) async {
      final router = await abrir(tester, rol: RolUsuario.cliente);
      // Así termina de crear la solicitud: `go`, que reemplaza la pila.
      router.go(Rutas.detalleSolicitud('s-1'));
      await tester.pumpAndSettle();

      expect(router.canPop(), isFalse);
      expect(flecha, findsOneWidget);
      await tocarFlecha(tester);
      expect(donde(router), Rutas.actividad);
    });

    testWidgets(
      'recién creada (sin pila): atrás del sistema no cierra la app',
      (tester) async {
        final router = await abrir(tester, rol: RolUsuario.cliente);
        router.go(Rutas.detalleSolicitud('s-1'));
        await tester.pumpAndSettle();

        await atrasDelSistema(tester);
        expect(donde(router), Rutas.actividad);
        expect(salidasDeLaApp, 0);
      },
    );

    testWidgets(
      'solicitud de la empresa en solo lectura: igual que el detalle',
      (tester) async {
        final router = await abrir(tester, rol: RolUsuario.empresaContacto);
        router.go(Rutas.detalleSolicitudSoloLectura('s-1'));
        await tester.pumpAndSettle();

        await atrasDelSistema(tester);
        expect(donde(router), Rutas.actividad);
        expect(salidasDeLaApp, 0);
      },
    );
  });

  group('formularios y chat: confirman antes de descartar lo escrito', () {
    /// Cómo abrir cada pantalla y cómo escribir algo en ella.
    final casos =
        <
          (
            String,
            RolUsuario?,
            String,
            Future<void> Function(WidgetTester),
            String,
          )
        >[];

    Future<void> escribir(
      WidgetTester tester,
      String tecla, [
      String texto = 'algo',
    ]) async {
      await tester.ensureVisible(clave(tecla));
      await tester.enterText(clave(tecla), texto);
      await tester.pump();
    }

    casos.addAll([
      (
        'Registro de cliente',
        null,
        Rutas.registro,
        (t) => escribir(t, 'campo-nombre'),
        Rutas.iniciarSesion,
      ),
      (
        'Registro de técnico',
        null,
        Rutas.registroTecnico,
        (t) => escribir(t, 'campo-nombre'),
        Rutas.iniciarSesion,
      ),
      (
        'Nueva solicitud',
        RolUsuario.cliente,
        Rutas.nuevaSolicitud,
        (t) => escribir(t, 'campo-descripcion'),
        Rutas.inicio,
      ),
      (
        'Agregar usuario de la empresa',
        RolUsuario.empresaContacto,
        Rutas.agregarUsuarioEmpresa,
        (t) => escribir(t, 'campo-nombre'),
        Rutas.inicio,
      ),
      (
        'Agregar técnico',
        RolUsuario.proveedor,
        Rutas.altaTecnico,
        (t) => escribir(t, 'campo-nombre'),
        Rutas.inicio,
      ),
      (
        'Pagar el servicio',
        RolUsuario.cliente,
        Rutas.pagarSolicitud('s-1'),
        // El número de la tarjeta solo admite dígitos.
        (t) => escribir(t, 'campo-numero', '4111'),
        Rutas.inicio,
      ),
      (
        'Chat del servicio (texto sin enviar)',
        RolUsuario.cliente,
        Rutas.chatSolicitud('s-1'),
        (t) => escribir(t, 'chat-texto'),
        Rutas.inicio,
      ),
      (
        'Disponibilidad y cobertura (localidades sin guardar)',
        RolUsuario.tecnico,
        Rutas.disponibilidad,
        (t) async {
          await t.ensureVisible(clave('localidad-01'));
          await t.tap(clave('localidad-01'));
          await t.pumpAndSettle();
        },
        Rutas.inicio,
      ),
    ]);

    /// Abre la pantalla y deja algo escrito.
    Future<GoRouter> conCambios(
      WidgetTester tester,
      RolUsuario? rol,
      String ruta,
      Future<void> Function(WidgetTester) cambiar,
    ) async {
      final router = await abrir(tester, rol: rol);
      if (rol == null) {
        final tecla = ruta == Rutas.registro
            ? 'boton-ir-registro'
            : 'boton-ir-registro-tecnico';
        await tester.ensureVisible(clave(tecla));
        await tester.tap(clave(tecla));
        await tester.pumpAndSettle();
      } else {
        await apilar(tester, router, ruta);
      }
      await cambiar(tester);
      return router;
    }

    for (final (nombre, rol, ruta, cambiar, origen) in casos) {
      testWidgets('$nombre: la flecha pregunta y "Seguir aquí" conserva todo', (
        tester,
      ) async {
        final router = await conCambios(tester, rol, ruta, cambiar);

        await tocarFlecha(tester);
        expect(clave('dialogo-confirmar-salida'), findsOneWidget);
        await tester.tap(clave('seguir-aqui'));
        await tester.pumpAndSettle();

        expect(clave('dialogo-confirmar-salida'), findsNothing);
        expect(donde(router), Uri.parse(ruta).path);
      });

      testWidgets('$nombre: la flecha pregunta y "Salir" descarta', (
        tester,
      ) async {
        final router = await conCambios(tester, rol, ruta, cambiar);

        await tocarFlecha(tester);
        await tester.tap(clave('confirmar-salir'));
        await tester.pumpAndSettle();

        expect(donde(router), origen);
        expect(salidasDeLaApp, 0);
      });

      testWidgets('$nombre: el botón atrás del sistema también pregunta', (
        tester,
      ) async {
        final router = await conCambios(tester, rol, ruta, cambiar);

        await atrasDelSistema(tester);
        expect(clave('dialogo-confirmar-salida'), findsOneWidget);
        expect(donde(router), Uri.parse(ruta).path);
        await tester.tap(clave('confirmar-salir'));
        await tester.pumpAndSettle();

        expect(donde(router), origen);
      });
    }

    testWidgets('Registro de cliente: sin nada escrito sale sin preguntar', (
      tester,
    ) async {
      final router = await abrir(tester);
      await tester.ensureVisible(clave('boton-ir-registro'));
      await tester.tap(clave('boton-ir-registro'));
      await tester.pumpAndSettle();

      await tocarFlecha(tester);
      expect(clave('dialogo-confirmar-salida'), findsNothing);
      expect(donde(router), Rutas.iniciarSesion);
    });

    testWidgets('Disponibilidad: si deshace el cambio, sale sin preguntar', (
      tester,
    ) async {
      final router = await abrir(tester, rol: RolUsuario.tecnico);
      await apilar(tester, router, Rutas.disponibilidad);
      await tester.ensureVisible(clave('localidad-01'));
      await tester.tap(clave('localidad-01'));
      await tester.pumpAndSettle();
      await tester.tap(clave('localidad-01'));
      await tester.pumpAndSettle();

      await tocarFlecha(tester);
      expect(clave('dialogo-confirmar-salida'), findsNothing);
      expect(donde(router), Rutas.inicio);
    });

    testWidgets('Chat: un mensaje en blanco no cuenta como texto sin enviar', (
      tester,
    ) async {
      final router = await abrir(tester, rol: RolUsuario.cliente);
      await apilar(tester, router, Rutas.chatSolicitud('s-1'));
      await tester.enterText(clave('chat-texto'), '   ');
      await tester.pump();

      await tocarFlecha(tester);
      expect(clave('dialogo-confirmar-salida'), findsNothing);
      expect(donde(router), Rutas.inicio);
    });
  });
}
