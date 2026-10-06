import 'package:flutter/material.dart';

/// Pantalla inicial provisional; la reemplaza el flujo de cada rol (cliente o técnico).
class InicioPage extends StatelessWidget {
  const InicioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QUICKPATCH')),
      body: const Center(child: Text('Servicios técnicos para tu hogar')),
    );
  }
}
