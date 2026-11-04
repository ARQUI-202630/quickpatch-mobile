/// Categoría activa del tenant (`Category` en `catalog.v1.yaml`).
class Categoria {
  const Categoria({required this.id, required this.nombre, this.descripcion});

  factory Categoria.desdeJson(Map<String, dynamic> json) => Categoria(
    id: json['id'] as String,
    nombre: json['name'] as String,
    descripcion: json['description'] as String?,
  );

  final String id;
  final String nombre;
  final String? descripcion;
}
