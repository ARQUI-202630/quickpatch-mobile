import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'accesibilidad.dart';

/// Control del ayudante de AC4-E7: una pantalla que incumple las guías tiene
/// que hacerlo fallar; si no, que las demás pantallas pasen no probaría nada.
void main() {
  testWidgets('detecta un área táctil pequeña y un texto sin contraste', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              GestureDetector(
                onTap: () {},
                child: Semantics(
                  button: true,
                  label: 'Botón pequeño',
                  child: const SizedBox(width: 20, height: 20),
                ),
              ),
              const Text(
                'Texto casi invisible',
                style: TextStyle(color: Color(0xFFEEEEEE)),
              ),
            ],
          ),
        ),
      ),
    );

    await expectLater(
      cumpleGuiasDeAccesibilidad(tester),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('deja pasar una pantalla que cumple las guías', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Enviar'),
            ),
          ),
        ),
      ),
    );

    await cumpleGuiasDeAccesibilidad(tester);
  });
}
