/// Valores de `users.role` (DD, sección 5.2).
enum RolUsuario {
  cliente('cliente'),
  empresaContacto('empresa_contacto'),
  tecnico('tecnico'),
  proveedor('proveedor'),
  adminTenant('admin_tenant'),
  adminPlataforma('admin_plataforma');

  const RolUsuario(this.valor);

  /// Valor tal como viaja en el contrato.
  final String valor;

  /// Convierte el valor del contrato; devuelve `null` si no lo reconoce.
  static RolUsuario? desdeValor(String? valor) {
    for (final rol in values) {
      if (rol.valor == valor) return rol;
    }
    return null;
  }

  /// La app móvil atiende a cliente, empresa cliente, técnico y proveedor;
  /// la administración usa el panel web (Angular).
  bool get usaAppMovil => switch (this) {
    cliente || empresaContacto || tecnico || proveedor => true,
    adminTenant || adminPlataforma => false,
  };
}
