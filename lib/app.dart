import 'package:flutter/material.dart';

import 'features/inicio/presentation/inicio_page.dart';

/// Raíz de la aplicación móvil de QUICKPATCH para clientes y técnicos.
class QuickpatchApp extends StatelessWidget {
  const QuickpatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QUICKPATCH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
      ),
      home: const InicioPage(),
    );
  }
}
