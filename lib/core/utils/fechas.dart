/// Fecha como `dd/mm/aaaa hh:mm`.
String fechaCorta(DateTime f) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(f.day)}/${dos(f.month)}/${f.year} ${dos(f.hour)}:${dos(f.minute)}';
}

/// "Hace 5 min", "Hace 3 h", "Ayer" o la fecha `dd/mm/aaaa`.
String fechaRelativa(DateTime fecha, DateTime ahora) {
  final diferencia = ahora.difference(fecha);
  if (diferencia.inMinutes < 1) return 'Hace un momento';
  if (diferencia.inHours < 1) return 'Hace ${diferencia.inMinutes} min';
  if (diferencia.inDays < 1) return 'Hace ${diferencia.inHours} h';
  if (diferencia.inDays == 1) return 'Ayer';
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year}';
}
