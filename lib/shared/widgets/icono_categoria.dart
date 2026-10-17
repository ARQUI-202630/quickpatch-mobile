import 'package:flutter/material.dart';

/// Ícono para una categoría de Catalog según su nombre. Las categorías las
/// define cada tenant, así que esto solo decora: si el nombre no coincide con
/// ninguna palabra conocida, se usa una herramienta genérica.
IconData iconoCategoria(String nombre) {
  final n = _sinTildes(nombre.toLowerCase());
  for (final (palabras, icono) in _iconos) {
    if (palabras.any(n.contains)) return icono;
  }
  return Icons.handyman_outlined;
}

// El orden importa: "electrodomésticos" antes que "eléctrico".
const _iconos = <(List<String>, IconData)>[
  (['electrodom'], Icons.kitchen_outlined),
  (['plom', 'fontan', 'tuberi'], Icons.plumbing_outlined),
  (['electri'], Icons.electrical_services_outlined),
  (['cerraj', 'chapa'], Icons.key_outlined),
  (['pintu'], Icons.format_paint_outlined),
  (['carpint', 'mueble'], Icons.carpenter_outlined),
  (['aire', 'refriger', 'clima'], Icons.ac_unit_outlined),
  (['jardin'], Icons.yard_outlined),
  (['limpie', 'aseo'], Icons.cleaning_services_outlined),
  (['gas'], Icons.local_fire_department_outlined),
  (['comput', 'tecnolog', 'internet'], Icons.computer_outlined),
  (['albañ', 'albanil', 'construc', 'remodel'], Icons.construction_outlined),
];

String _sinTildes(String texto) => texto
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u');
