import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/app/theme/tokens.dart';

/// Razón de contraste WCAG 2.x entre dos colores opacos.
double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (claro, oscuro) = la > lb ? (la, lb) : (lb, la);
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  test('el primario del tema claro es el azul de marca #00468C', () {
    expect(AppTheme.claro().colorScheme.primary, const Color(0xFF00468C));
    expect(AppTheme.claro().colorScheme.primary, QpColores.azul700);
  });

  test('ya no queda la semilla verde', () {
    for (final tema in [AppTheme.claro(), AppTheme.oscuro()]) {
      expect(tema.colorScheme.primary, isNot(const Color(0xFF0B6E4F)));
    }
  });

  for (final (nombre, esquema, estados) in [
    ('claro', AppTheme.esquemaClaro, QpEstados.claro),
    ('oscuro', AppTheme.esquemaOscuro, QpEstados.oscuro),
  ]) {
    group('contraste WCAG AA del tema $nombre', () {
      final texto = <String, (Color, Color)>{
        'onPrimary/primary': (esquema.onPrimary, esquema.primary),
        'onPrimaryContainer/primaryContainer': (
          esquema.onPrimaryContainer,
          esquema.primaryContainer,
        ),
        'onSecondaryContainer/secondaryContainer': (
          esquema.onSecondaryContainer,
          esquema.secondaryContainer,
        ),
        'onSurface/surface': (esquema.onSurface, esquema.surface),
        'onSurfaceVariant/surface': (esquema.onSurfaceVariant, esquema.surface),
        'onSurfaceVariant/surfaceContainerHighest': (
          esquema.onSurfaceVariant,
          esquema.surfaceContainerHighest,
        ),
        'primary/surface': (esquema.primary, esquema.surface),
        'error/surface': (esquema.error, esquema.surface),
        'onError/error': (esquema.onError, esquema.error),
        'onErrorContainer/errorContainer': (
          esquema.onErrorContainer,
          esquema.errorContainer,
        ),
        'onInverseSurface/inverseSurface': (
          esquema.onInverseSurface,
          esquema.inverseSurface,
        ),
        'exito/exitoFondo': (estados.exito, estados.exitoFondo),
        'aviso/avisoFondo': (estados.aviso, estados.avisoFondo),
        'peligro/peligroFondo': (estados.peligro, estados.peligroFondo),
        'info/infoFondo': (estados.info, estados.infoFondo),
      };
      for (final MapEntry(key: par, value: (frente, fondo)) in texto.entries) {
        test('texto $par ≥ 4.5:1', () {
          expect(contraste(frente, fondo), greaterThanOrEqualTo(4.5));
        });
      }

      // WCAG 1.4.11: bordes de campos y controles ≥ 3:1.
      for (final fondo in [esquema.surface, esquema.surfaceContainerLowest]) {
        test('borde outline ≥ 3:1 sobre $fondo', () {
          expect(contraste(esquema.outline, fondo), greaterThanOrEqualTo(3));
        });
      }
    });
  }

  test('ambos temas traen la extensión de estados y la fuente', () {
    expect(AppTheme.claro().extension<QpEstados>(), QpEstados.claro);
    expect(AppTheme.oscuro().extension<QpEstados>(), QpEstados.oscuro);
    expect(AppTheme.claro().textTheme.bodyLarge?.fontFamily, AppTheme.fuente);
  });

  test('cada estilo fija el eje wght de la fuente variable', () {
    final estilos = AppTheme.escala;
    for (final estilo in [
      estilos.headlineMedium,
      estilos.titleLarge,
      estilos.bodyLarge,
      estilos.labelLarge,
    ]) {
      expect(
        estilo!.fontVariations!.single.value,
        estilo.fontWeight!.value.toDouble(),
      );
    }
  });

  test('QpEstados interpola y copia', () {
    const a = QpEstados.claro;
    expect(a.lerp(null, 0.5), same(a));
    expect(a.lerp(QpEstados.oscuro, 1).exito, QpEstados.oscuro.exito);
    expect(a.copyWith(info: QpColores.azul500).info, QpColores.azul500);
    expect(a.copyWith().peligro, a.peligro);
  });

  Widget conTema(Widget hijo, {double escalaTexto = 1}) => MaterialApp(
    theme: AppTheme.claro(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(escalaTexto)),
      child: Scaffold(body: Center(child: hijo)),
    ),
  );

  testWidgets('los botones tienen al menos 48 px de alto', (tester) async {
    await tester.pumpWidget(
      conTema(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(onPressed: () {}, child: const Text('Ingresar')),
            OutlinedButton(onPressed: () {}, child: const Text('Cancelar')),
            TextButton(onPressed: () {}, child: const Text('Registro')),
          ],
        ),
      ),
    );
    for (final tipo in [FilledButton, OutlinedButton, TextButton]) {
      expect(
        tester.getSize(find.byType(tipo)).height,
        greaterThanOrEqualTo(qpAltoControl),
      );
    }
  });

  testWidgets('con texto al 200 % el botón crece sin desbordarse (AC4-E7)', (
    tester,
  ) async {
    await tester.pumpWidget(
      conTema(
        FilledButton(onPressed: () {}, child: const Text('Ingresar')),
        escalaTexto: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThan(qpAltoControl),
    );
  });

  testWidgets('context.estados lee la extensión del tema', (tester) async {
    late QpEstados leidos;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.oscuro(),
        home: Builder(
          builder: (context) {
            leidos = context.estados;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(leidos, QpEstados.oscuro);
  });

  testWidgets('context.estados usa el claro si el tema no la trae', (
    tester,
  ) async {
    late QpEstados leidos;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            leidos = context.estados;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(leidos, QpEstados.claro);
  });
}
