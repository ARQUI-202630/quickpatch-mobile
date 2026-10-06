import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/features/inicio/presentation/inicio_page.dart';

void main() {
  testWidgets('muestra el mensaje de bienvenida', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: InicioPage()));

    expect(find.text('Servicios técnicos para tu hogar'), findsOneWidget);
  });
}
