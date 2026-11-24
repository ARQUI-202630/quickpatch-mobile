import 'package:flutter_test/flutter_test.dart';

/// Guías de accesibilidad de Flutter (AC4-E7): área táctil mínima de Android
/// (48 dp) y de iOS (44 pt), etiquetas en lo que se toca y contraste de texto.
/// Junta todos los fallos antes de fallar, para ver cuáles incumple la pantalla.
Future<void> cumpleGuiasDeAccesibilidad(WidgetTester tester) async {
  final semantica = tester.ensureSemantics();
  try {
    final guias = <String, AccessibilityGuideline>{
      'área táctil de Android (48 dp)': androidTapTargetGuideline,
      'área táctil de iOS (44 pt)': iOSTapTargetGuideline,
      'etiquetas en lo que se toca': labeledTapTargetGuideline,
      'contraste del texto': textContrastGuideline,
    };
    final fallos = <String>[];
    for (final MapEntry(key: nombre, value: guia) in guias.entries) {
      final resultado = await guia.evaluate(tester);
      if (!resultado.passed) fallos.add('$nombre: ${resultado.reason}');
    }
    expect(fallos, isEmpty, reason: fallos.join('\n'));
  } finally {
    semantica.dispose();
  }
}
