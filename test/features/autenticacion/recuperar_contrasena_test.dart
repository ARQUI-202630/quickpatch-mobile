import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/app.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/core/errors/app_exception.dart';
import 'package:quickpatch_mobile/core/errors/codigo_error.dart';
import 'package:quickpatch_mobile/core/network/cliente_api.dart';
import 'package:quickpatch_mobile/core/session/almacen_sesion.dart';
import 'package:quickpatch_mobile/features/autenticacion/presentation/paginas/inicio_sesion_page.dart';
import 'package:quickpatch_mobile/features/autenticacion/presentation/paginas/recuperar_contrasena_page.dart';

import '../../helpers/fakes.dart';

/// SCRUM-626: el usuario pide la recuperación de su contraseña desde el
/// inicio de sesión (`POST /v1/auth/password-recovery`, identity 1.10.0).
const _ruta = '/v1/auth/password-recovery';

/// Problem Details con `Retry-After`, como el `429` del contrato.
ResponseBody _demasiadas([String? segundos = '600']) => ResponseBody.fromString(
  jsonEncode({
    'type': 'https://quickpatch.internal/problems/demasiadas-solicitudes',
    'title': 'Demasiadas solicitudes',
    'status': 429,
  }),
  429,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    'retry-after': ?(segundos == null ? null : [segundos]),
  },
);

void main() {
  late List<RequestOptions> peticiones;
  late ResponseBody Function() respuesta;

  setUp(() {
    peticiones = [];
    respuesta = () => ResponseBody.fromString('', 202);
  });

  Future<void> abrirLogin(
    WidgetTester tester, {
    ThemeData? tema,
    double escalaTexto = 1,
  }) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = escalaTexto;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    if (tema != null) {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    }
    final container = ProviderContainer(
      overrides: [
        almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
      ],
    );
    addTearDown(container.dispose);
    container.read(clienteApiProvider).httpClientAdapter = AdaptadorFalso((o) {
      peticiones.add(o);
      return respuesta();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QuickpatchApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder clave(String k) => find.byKey(Key(k));

  Future<void> tocar(WidgetTester tester, Finder objetivo) async {
    await tester.ensureVisible(objetivo);
    await tester.tap(objetivo);
    await tester.pumpAndSettle();
  }

  /// Abre la pantalla desde el login, con [email] escrito en el login.
  Future<void> abrir(
    WidgetTester tester, {
    String email = '',
    ThemeData? tema,
    double escalaTexto = 1,
  }) async {
    await abrirLogin(tester, tema: tema, escalaTexto: escalaTexto);
    if (email.isNotEmpty) {
      await tester.enterText(clave('campo-email'), email);
    }
    await tocar(tester, clave('boton-olvide-contrasena'));
  }

  Iterable<RequestOptions> envios() =>
      peticiones.where((p) => p.path.endsWith(_ruta));

  testWidgets('desde el login pide la recuperación con el correo escrito', (
    tester,
  ) async {
    await abrir(tester, email: 'ana@correo.co');
    expect(find.byType(RecuperarContrasenaPage), findsOneWidget);
    expect(find.text('ana@correo.co'), findsOneWidget);

    await tocar(tester, clave('boton-recuperar'));

    final envio = envios().single;
    expect(envio.method, 'POST');
    expect(envio.data, {'email': 'ana@correo.co'});
    // Pública: lleva el canal y nunca un token ni el tenant.
    expect(envio.headers['X-Channel-Id'], isNotNull);
    expect(envio.headers.containsKey('Authorization'), isFalse);
    expect(clave('recuperacion-enviada'), findsOneWidget);
    expect(find.textContaining('Si el correo está registrado'), findsOneWidget);
    expect(find.textContaining('vence en 1 hora'), findsOneWidget);

    // Ya enviada, volver no pide confirmación.
    await tocar(tester, find.text('Volver a iniciar sesión'));
    expect(find.byType(InicioSesionPage), findsOneWidget);
  });

  testWidgets('valida el correo antes de enviar', (tester) async {
    await abrir(tester);

    await tocar(tester, clave('boton-recuperar'));
    expect(find.text('Escribe tu correo.'), findsOneWidget);

    await tester.enterText(clave('campo-email'), 'ana@');
    await tocar(tester, clave('boton-recuperar'));
    expect(find.textContaining('Escribe un correo válido'), findsOneWidget);
    expect(envios(), isEmpty);
  });

  testWidgets('quita los espacios y envía con la tecla del teclado', (
    tester,
  ) async {
    await abrir(tester);
    await tester.enterText(clave('campo-email'), '  luis@correo.co ');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(envios().single.data, {'email': 'luis@correo.co'});
    expect(clave('recuperacion-enviada'), findsOneWidget);
  });

  testWidgets('el 429 dice cuánto esperar según Retry-After', (tester) async {
    respuesta = _demasiadas;
    await abrir(tester, email: 'ana@correo.co');

    await tocar(tester, clave('boton-recuperar'));
    expect(
      find.text(
        'Ya pediste la recuperación varias veces. Intenta de nuevo en '
        '10 minutos.',
      ),
      findsOneWidget,
    );
    expect(clave('recuperacion-enviada'), findsNothing);

    respuesta = () => _demasiadas('30');
    await tocar(tester, clave('boton-recuperar'));
    expect(find.textContaining('en 1 minuto.'), findsOneWidget);

    respuesta = () => _demasiadas(null);
    await tocar(tester, clave('boton-recuperar'));
    expect(find.text(CodigoError.tooManyRequests.mensaje), findsOneWidget);
  });

  testWidgets('el error del correo va bajo el campo', (tester) async {
    respuesta = () => respuestaJson({
      'type': 'https://quickpatch.internal/problems/validacion',
      'status': 400,
      'errors': {
        'email': ['No es un correo válido.'],
      },
    }, 400);
    await abrir(tester, email: 'ana@correo.co');

    await tocar(tester, clave('boton-recuperar'));
    expect(find.text('No es un correo válido.'), findsOneWidget);
    expect(clave('mensaje-error'), findsNothing);
  });

  testWidgets('sin conexión muestra el mensaje general', (tester) async {
    respuesta = () => respuestaJson(<String, dynamic>{}, 503);
    await abrir(tester, email: 'ana@correo.co');

    await tocar(tester, clave('boton-recuperar'));
    expect(clave('mensaje-error'), findsOneWidget);
  });

  testWidgets('el correo que llegó del login no pide confirmación al salir', (
    tester,
  ) async {
    await abrir(tester, email: 'ana@correo.co');
    await tocar(tester, find.byType(BackButton));
    expect(find.byType(InicioSesionPage), findsOneWidget);
    expect(clave('dialogo-confirmar-salida'), findsNothing);
  });

  testWidgets('si cambió el correo, salir pide confirmación', (tester) async {
    await abrir(tester);
    await tester.enterText(clave('campo-email'), 'ana@correo.co');
    await tester.pump();

    await tocar(tester, find.byType(BackButton));
    expect(clave('dialogo-confirmar-salida'), findsOneWidget);

    await tocar(tester, clave('confirmar-salir'));
    expect(find.byType(InicioSesionPage), findsOneWidget);
  });

  testWidgets('tema oscuro y texto al 200 % sin desbordes', (tester) async {
    await abrir(tester, tema: AppTheme.oscuro(), escalaTexto: 2);
    expect(tester.takeException(), isNull);

    await tester.enterText(clave('campo-email'), 'ana@correo.co');
    await tocar(tester, clave('boton-recuperar'));
    expect(tester.takeException(), isNull);
    expect(clave('recuperacion-enviada'), findsOneWidget);
  });

  test('lee Retry-After del 429; sin número queda en null', () {
    AppException desde(String? valor) => AppException.desdeDio(
      DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(),
          statusCode: 429,
          data: {
            'type':
                'https://quickpatch.internal/problems/demasiadas-solicitudes',
          },
          headers: Headers.fromMap({
            'retry-after': ?(valor == null ? null : [valor]),
          }),
        ),
      ),
    );

    final conEspera = desde('120');
    expect(conEspera.codigo, CodigoError.tooManyRequests);
    expect(conEspera.reintentarEn, const Duration(minutes: 2));
    expect(desde(null).reintentarEn, isNull);
    expect(desde('mañana').reintentarEn, isNull);
    expect(desde('-5').reintentarEn, isNull);
  });
}
