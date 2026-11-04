import 'package:flutter/material.dart';

/// Pantalla de espera mientras se restaura la sesión.
class VistaCargando extends StatelessWidget {
  const VistaCargando({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator(semanticsLabel: 'Cargando')),
  );
}
