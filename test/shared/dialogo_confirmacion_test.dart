import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/app/theme/tokens.dart';
import 'package:quickpatch_mobile/shared/widgets/confirmar_salida.dart';
import 'package:quickpatch_mobile/shared/widgets/dialogo_confirmacion.dart';

/// SCRUM-638: diálogo de confirmación compartido de la app.
void main() {
  /// Pantalla con un botón «Abrir» que corre [alAbrir].
  Future<void> montar(
    WidgetTester tester,
    Future<void> Function(BuildContext) alAbrir, {
    ThemeData? tema,
    double escalaTexto = 1,
  }) async {
    tester.platformDispatcher.textScaleFactorTestValue = escalaTexto;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: tema ?? AppTheme.claro(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => alAbrir(context),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> abrir(WidgetTester tester) async {
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  /// Color de fondo del botón que confirma, o `null` si usa el del tema.
  Color? fondo(WidgetTester tester, Finder boton) => tester
      .widget<FilledButton>(boton)
      .style
      ?.backgroundColor
      ?.resolve(const {});

  group('confirmar', () {
    late bool? resultado;

    Future<void> preguntar(BuildContext context, {bool peligro = false}) async {
      resultado = await confirmar(
        context,
        titulo: '¿Rechazar esta oferta?',
        mensaje: 'No tiene penalización.',
        accion: 'Rechazar',
        peligro: peligro,
        clave: const Key('confirmar'),
      );
    }

    setUp(() => resultado = null);

    testWidgets('muestra título, mensaje, «Volver» y la acción', (
      tester,
    ) async {
      await montar(tester, preguntar);
      await abrir(tester);

      expect(find.text('¿Rechazar esta oferta?'), findsOneWidget);
      expect(find.text('No tiene penalización.'), findsOneWidget);
      expect(find.text('Volver'), findsOneWidget);
      expect(find.text('Rechazar'), findsOneWidget);
      // Sin peligro, el botón usa el color primario del tema.
      expect(fondo(tester, find.byKey(const Key('confirmar'))), isNull);
    });

    testWidgets('confirmar devuelve true', (tester) async {
      await montar(tester, preguntar);
      await abrir(tester);
      await tester.tap(find.byKey(const Key('confirmar')));
      await tester.pumpAndSettle();

      expect(resultado, isTrue);
      expect(find.byType(DialogoConfirmacion), findsNothing);
    });

    testWidgets('volver, tocar fuera o el botón atrás devuelven false', (
      tester,
    ) async {
      await montar(tester, preguntar);

      await abrir(tester);
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(resultado, isFalse);

      resultado = null;
      await abrir(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(resultado, isFalse);

      resultado = null;
      await abrir(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(resultado, isFalse);
    });

    testWidgets('con peligro, la acción va en el rojo de los estados', (
      tester,
    ) async {
      await montar(tester, (c) => preguntar(c, peligro: true));
      await abrir(tester);

      expect(
        fondo(tester, find.byKey(const Key('confirmar'))),
        QpEstados.claro.peligro,
      );
    });

    testWidgets('tema oscuro y texto al 200 % sin desbordes', (tester) async {
      await montar(
        tester,
        (c) => preguntar(c, peligro: true),
        tema: AppTheme.oscuro(),
        escalaTexto: 2,
      );
      await abrir(tester);

      expect(tester.takeException(), isNull);
      expect(
        fondo(tester, find.byKey(const Key('confirmar'))),
        QpEstados.oscuro.peligro,
      );
    });
  });

  group('DialogoConfirmacion', () {
    testWidgets('mientras envía, deshabilita los dos botones y lo anuncia', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      var confirmaciones = 0;
      await montar(
        tester,
        (context) => showDialog<void>(
          context: context,
          builder: (_) => DialogoConfirmacion(
            titulo: '¿Cancelar la solicitud?',
            contenido: const Text('No podrás reactivarla.'),
            accion: 'Cancelar solicitud',
            peligro: true,
            enviando: true,
            etiquetaEnviando: 'Cancelando',
            claveConfirmar: const Key('confirmar'),
            alConfirmar: () => confirmaciones++,
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final boton = tester.widget<FilledButton>(
        find.byKey(const Key('confirmar')),
      );
      expect(boton.onPressed, isNull);
      expect(
        tester
            .widget<TextButton>(
              find.ancestor(
                of: find.text('Volver'),
                matching: find.byType(TextButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Cancelando'), findsOneWidget);
      expect(find.text('Cancelar solicitud'), findsNothing);
      expect(confirmaciones, 0);
      semantica.dispose();
    });

    testWidgets('sin alVolver, «Volver» cierra el diálogo sin resultado', (
      tester,
    ) async {
      Object? resultado = 'sin cerrar';
      await montar(
        tester,
        (context) async => resultado = await showDialog<String>(
          context: context,
          builder: (_) => DialogoConfirmacion(
            titulo: '¿Rechazar la cotización?',
            contenido: const Text('El técnico podrá enviarte otra.'),
            accion: 'Rechazar',
            alConfirmar: () {},
          ),
        ),
      );
      await abrir(tester);
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      expect(resultado, isNull);
    });
  });

  testWidgets('ConfirmarSalida usa el diálogo con «Seguir aquí» y en rojo', (
    tester,
  ) async {
    final controlador = TextEditingController(text: 'algo escrito');
    addTearDown(controlador.dispose);
    await montar(
      tester,
      (context) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConfirmarSalida.conTextos(
            controladores: [controlador],
            child: Scaffold(appBar: AppBar(), body: const SizedBox()),
          ),
        ),
      ),
    );
    await abrir(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialogo-confirmar-salida')), findsOneWidget);
    expect(find.text('Seguir aquí'), findsOneWidget);
    expect(
      fondo(tester, find.byKey(const Key('confirmar-salir'))),
      QpEstados.claro.peligro,
    );
  });
}
