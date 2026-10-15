import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/shell/inicio_page.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/app/theme/tokens.dart';
import 'package:quickpatch_mobile/core/errors/app_exception.dart';
import 'package:quickpatch_mobile/core/errors/codigo_error.dart';
import 'package:quickpatch_mobile/shared/widgets/boton_principal.dart';
import 'package:quickpatch_mobile/shared/widgets/botones.dart';
import 'package:quickpatch_mobile/shared/widgets/campo_contrasena.dart';
import 'package:quickpatch_mobile/shared/widgets/mensaje_error.dart';
import 'package:quickpatch_mobile/shared/widgets/vista_error.dart';

Widget _conTema(Widget hijo) => MaterialApp(
  theme: AppTheme.claro(),
  home: Scaffold(body: Center(child: hijo)),
);

void main() {
  group('CampoContrasena', () {
    testWidgets('oculta la contraseña y la muestra al tocar el ojo', (
      tester,
    ) async {
      final controlador = TextEditingController(text: 'secreta123');
      addTearDown(controlador.dispose);
      await tester.pumpWidget(
        _conTema(
          CampoContrasena(controlador: controlador, etiqueta: 'Contraseña'),
        ),
      );
      bool oculta() =>
          tester.widget<EditableText>(find.byType(EditableText)).obscureText;

      expect(oculta(), isTrue);
      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pump();
      expect(oculta(), isFalse);
      await tester.tap(find.byTooltip('Ocultar contraseña'));
      await tester.pump();
      expect(oculta(), isTrue);
    });

    testWidgets('muestra el error del backend junto al campo', (tester) async {
      final controlador = TextEditingController();
      addTearDown(controlador.dispose);
      await tester.pumpWidget(
        _conTema(
          CampoContrasena(
            controlador: controlador,
            etiqueta: 'Contraseña',
            textoError: 'Muy corta.',
          ),
        ),
      );
      expect(find.text('Muy corta.'), findsOneWidget);
    });
  });

  group('BotonPrincipal', () {
    testWidgets('mientras carga se deshabilita y muestra el indicador', (
      tester,
    ) async {
      var veces = 0;
      await tester.pumpWidget(
        _conTema(
          BotonPrincipal(
            texto: 'Enviar',
            cargando: true,
            icono: Icons.send,
            alPresionar: () => veces++,
          ),
        ),
      );
      expect(find.text('Enviar'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      expect(veces, 0);
    });

    testWidgets('con ícono lo muestra y responde al toque', (tester) async {
      var veces = 0;
      await tester.pumpWidget(
        _conTema(
          BotonPrincipal(
            texto: 'Enviar',
            icono: Icons.send,
            alPresionar: () => veces++,
          ),
        ),
      );
      expect(find.byIcon(Icons.send), findsOneWidget);
      await tester.tap(find.text('Enviar'));
      expect(veces, 1);
    });
  });

  testWidgets('MensajeError usa los colores de peligro del tema', (
    tester,
  ) async {
    await tester.pumpWidget(_conTema(const MensajeError('Algo falló.')));
    final texto = tester.widget<Text>(find.text('Algo falló.'));
    expect(texto.style?.color, QpEstados.claro.peligro);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  group('NombreCategoria', () {
    testWidgets('una palabra larga se reduce en vez de partirse', (
      tester,
    ) async {
      await tester.pumpWidget(
        _conTema(
          const SizedBox(
            width: 120,
            child: NombreCategoria('Electrodomésticos'),
          ),
        ),
      );
      expect(find.byType(FittedBox), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un nombre de varias palabras pasa de línea', (tester) async {
      await tester.pumpWidget(
        _conTema(
          const SizedBox(
            width: 120,
            child: NombreCategoria('Aire acondicionado'),
          ),
        ),
      );
      expect(find.byType(FittedBox), findsNothing);
    });
  });

  group('VistaError', () {
    testWidgets('muestra el mensaje del código de error y reintenta', (
      tester,
    ) async {
      var reintentos = 0;
      await tester.pumpWidget(
        _conTema(
          VistaError(
            error: const AppException(CodigoError.sinConexion),
            titulo: 'No pudimos cargar',
            alReintentar: () => reintentos++,
          ),
        ),
      );
      expect(find.text('No pudimos cargar'), findsOneWidget);
      expect(
        find.text(const AppException(CodigoError.sinConexion).mensaje),
        findsOneWidget,
      );
      await tester.tap(find.text('Reintentar'));
      expect(reintentos, 1);
    });

    testWidgets('con otro error no muestra detalle ni botón sin acción', (
      tester,
    ) async {
      await tester.pumpWidget(
        _conTema(
          VistaError(error: StateError('x'), titulo: 'No pudimos cargar'),
        ),
      );
      expect(find.text('Reintentar'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
    });
  });

  testWidgets('IndicadorCarga anuncia su etiqueta', (tester) async {
    await tester.pumpWidget(
      _conTema(const IndicadorCarga(etiqueta: 'Cargando ofertas')),
    );
    expect(find.bySemanticsLabel('Cargando ofertas'), findsOneWidget);
  });

  group('BotonSecundario y BotonPeligro', () {
    testWidgets('sin ícono responden al toque', (tester) async {
      var veces = 0;
      await tester.pumpWidget(
        _conTema(
          Column(
            children: [
              BotonSecundario(texto: 'Ver', alPresionar: () => veces++),
              BotonPeligro(texto: 'Rechazar', alPresionar: () => veces++),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Ver'));
      await tester.tap(find.text('Rechazar'));
      expect(veces, 2);
    });

    testWidgets('el de peligro usa el color de error del tema', (tester) async {
      await tester.pumpWidget(
        _conTema(
          BotonPeligro(
            texto: 'Rechazar',
            icono: Icons.close,
            alPresionar: () {},
          ),
        ),
      );
      final boton = tester.widget<OutlinedButton>(
        find.byWidgetPredicate((w) => w is OutlinedButton),
      );
      expect(
        boton.style?.foregroundColor?.resolve({}),
        AppTheme.claro().colorScheme.error,
      );
    });
  });
}
