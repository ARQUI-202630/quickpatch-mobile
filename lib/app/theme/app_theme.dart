import 'package:flutter/material.dart';

import 'tokens.dart';

/// Tema de la app con la identidad azul de QUICKPATCH (SCRUM-440).
///
/// Material 3 con áreas táctiles de al menos 48 px y sin alturas fijas de
/// texto, para cumplir AC4-E7 (texto al 200 %). Los esquemas de color se
/// arman a mano desde [QpColores] en vez de `ColorScheme.fromSeed`, porque la
/// semilla corre el tono y deja el azul de marca (#00468C) fuera del primario.
abstract final class AppTheme {
  /// Plus Jakarta Sans variable, autoalojada en `assets/fonts/` (OFL).
  static const fuente = 'PlusJakartaSans';

  static ThemeData claro() => _tema(esquemaClaro, QpEstados.claro);

  static ThemeData oscuro() => _tema(esquemaOscuro, QpEstados.oscuro);

  /// Pares de texto ≥ 4.5:1 y bordes ≥ 3:1 (WCAG AA); los verifica
  /// `test/app/theme/app_theme_test.dart`.
  static const esquemaClaro = ColorScheme(
    brightness: Brightness.light,
    primary: QpColores.azul700,
    onPrimary: QpColores.neutro0,
    primaryContainer: QpColores.azul100,
    onPrimaryContainer: QpColores.azul900,
    secondary: QpColores.azul600,
    onSecondary: QpColores.neutro0,
    secondaryContainer: QpColores.azul50,
    onSecondaryContainer: QpColores.azul800,
    tertiary: QpColores.verde700,
    onTertiary: QpColores.neutro0,
    tertiaryContainer: QpColores.verde50,
    onTertiaryContainer: QpColores.verde900,
    error: QpColores.rojo700,
    onError: QpColores.neutro0,
    errorContainer: QpColores.rojo50,
    onErrorContainer: QpColores.rojo900,
    surface: QpColores.neutro25,
    onSurface: QpColores.neutro900,
    onSurfaceVariant: QpColores.neutro600,
    surfaceContainerLowest: QpColores.neutro0,
    surfaceContainerLow: QpColores.neutro0,
    surfaceContainer: QpColores.neutro50,
    surfaceContainerHigh: QpColores.neutro100,
    surfaceContainerHighest: QpColores.neutro200,
    outline: QpColores.neutro500,
    outlineVariant: QpColores.neutro200,
    inverseSurface: QpColores.neutro850,
    onInverseSurface: QpColores.neutro50,
    inversePrimary: QpColores.azul300,
    shadow: QpColores.azul950,
    scrim: QpColores.azul950,
    surfaceTint: Colors.transparent,
  );

  static const esquemaOscuro = ColorScheme(
    brightness: Brightness.dark,
    primary: QpColores.azul300,
    onPrimary: QpColores.azul950,
    primaryContainer: QpColores.azul800,
    onPrimaryContainer: QpColores.azul100,
    secondary: QpColores.azul200,
    onSecondary: QpColores.azul950,
    secondaryContainer: QpColores.azul900,
    onSecondaryContainer: QpColores.azul100,
    tertiary: QpColores.verde200,
    onTertiary: QpColores.verde900,
    tertiaryContainer: QpColores.verde900,
    onTertiaryContainer: QpColores.verde50,
    error: QpColores.rojo200,
    onError: QpColores.rojo900,
    errorContainer: QpColores.rojo900,
    onErrorContainer: QpColores.rojo50,
    surface: QpColores.neutro950,
    onSurface: QpColores.neutro50,
    onSurfaceVariant: QpColores.neutro300,
    surfaceContainerLowest: QpColores.neutro950,
    surfaceContainerLow: QpColores.neutro900,
    surfaceContainer: QpColores.neutro900,
    surfaceContainerHigh: QpColores.neutro850,
    surfaceContainerHighest: QpColores.neutro800,
    outline: QpColores.neutro500,
    outlineVariant: QpColores.neutro700,
    inverseSurface: QpColores.neutro100,
    onInverseSurface: QpColores.neutro900,
    inversePrimary: QpColores.azul700,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  /// La fuente es variable: `fontWeight` no siempre mueve el eje `wght`, así
  /// que cada estilo fija también la variación.
  static TextStyle _estilo(
    double tamano,
    FontWeight peso, {
    double altura = 1.4,
    double tracking = 0,
  }) => TextStyle(
    fontSize: tamano,
    fontWeight: peso,
    fontVariations: [FontVariation.weight(peso.value.toDouble())],
    height: altura,
    letterSpacing: tracking,
  );

  /// Escala del panel web (12–28 px) con los roles de Material 3. Los títulos
  /// llevan el tracking de `--qp-tracking-titulo` (-0.015em).
  static final escala = TextTheme(
    displaySmall: _estilo(32, FontWeight.w700, altura: 1.2, tracking: -0.5),
    headlineMedium: _estilo(28, FontWeight.w700, altura: 1.25, tracking: -0.4),
    headlineSmall: _estilo(22, FontWeight.w700, altura: 1.3, tracking: -0.3),
    titleLarge: _estilo(20, FontWeight.w700, altura: 1.3, tracking: -0.3),
    titleMedium: _estilo(18, FontWeight.w600, altura: 1.35),
    titleSmall: _estilo(16, FontWeight.w600),
    bodyLarge: _estilo(16, FontWeight.w400, altura: 1.5),
    bodyMedium: _estilo(14, FontWeight.w400, altura: 1.45),
    bodySmall: _estilo(12, FontWeight.w400),
    labelLarge: _estilo(14, FontWeight.w600, altura: 1.3),
    labelMedium: _estilo(12, FontWeight.w600, altura: 1.3),
    labelSmall: _estilo(11, FontWeight.w600, altura: 1.3, tracking: 0.2),
  );

  static ThemeData _tema(ColorScheme esquema, QpEstados estados) {
    final base = ThemeData(
      colorScheme: esquema,
      fontFamily: fuente,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
    final texto = base.textTheme.merge(escala);
    final redondeoControl = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(QpRadio.md),
    );
    const tamanoControl = Size(64, qpAltoControl);
    const relleno = EdgeInsets.symmetric(
      horizontal: QpEspacio.e5,
      vertical: QpEspacio.e3,
    );

    OutlineInputBorder borde(Color color, [double ancho = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(QpRadio.md),
          borderSide: BorderSide(color: color, width: ancho),
        );

    return base.copyWith(
      textTheme: texto,
      scaffoldBackgroundColor: esquema.surface,
      extensions: [estados],
      appBarTheme: AppBarTheme(
        backgroundColor: esquema.surface,
        foregroundColor: esquema.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: texto.titleLarge?.copyWith(color: esquema.onSurface),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: tamanoControl,
          padding: relleno,
          shape: redondeoControl,
          textStyle: texto.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: tamanoControl,
          padding: relleno,
          shape: redondeoControl,
          textStyle: texto.labelLarge,
          side: BorderSide(color: esquema.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: tamanoControl,
          shape: redondeoControl,
          textStyle: texto.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: esquema.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: QpEspacio.e4,
          vertical: QpEspacio.e4,
        ),
        border: borde(esquema.outline),
        enabledBorder: borde(esquema.outline),
        focusedBorder: borde(esquema.primary, 2),
        errorBorder: borde(esquema.error),
        focusedErrorBorder: borde(esquema.error, 2),
        disabledBorder: borde(esquema.outlineVariant),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: esquema.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(QpRadio.lg),
          side: BorderSide(color: esquema.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(QpRadio.sm),
        ),
        labelStyle: texto.labelMedium,
      ),
      dividerTheme: DividerThemeData(
        color: esquema.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(QpRadio.md),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(QpRadio.lg)),
        ),
      ),
    );
  }
}
