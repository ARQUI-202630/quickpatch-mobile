import 'package:flutter/material.dart';

/// Tema de la app. Material 3 con áreas táctiles de al menos 48 px y sin
/// alturas fijas de texto, para cumplir AC4-E7 (texto al 200 %).
abstract final class AppTheme {
  static const _semilla = Color(0xFF0B6E4F);

  static ThemeData claro() => _tema(Brightness.light);

  static ThemeData oscuro() => _tema(Brightness.dark);

  static ThemeData _tema(Brightness brillo) => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _semilla, brightness: brillo),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}
