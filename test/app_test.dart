import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app.dart';

void main() {
  testWidgets('la app arranca en la pantalla de inicio', (tester) async {
    await tester.pumpWidget(const QuickpatchApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('QUICKPATCH'), findsOneWidget);
  });
}
