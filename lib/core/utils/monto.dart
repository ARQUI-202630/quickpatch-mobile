/// Monto en pesos colombianos. El contrato lo envía como cadena decimal con
/// dos cifras (`"185000.00"`, DD sección 8.1) para que ningún cliente
/// redondee con `double`; esta clase nunca lo convierte a punto flotante.
class Monto {
  Monto(this.valor) {
    if (!_formato.hasMatch(valor)) {
      throw FormatException('Monto inválido: $valor');
    }
  }

  static final _formato = RegExp(r'^\d+\.\d{2}$');

  /// Valor exacto del contrato.
  final String valor;

  /// Texto para mostrar, por ejemplo `$ 185.000` o `$ 1.250,50`.
  String formatear() {
    final partes = valor.split('.');
    final enteros = partes[0].replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final grupos = <String>[];
    for (var fin = enteros.length; fin > 0; fin -= 3) {
      grupos.insert(0, enteros.substring(fin - 3 < 0 ? 0 : fin - 3, fin));
    }
    final centavos = partes[1] == '00' ? '' : ',${partes[1]}';
    return '\$ ${grupos.join('.')}$centavos';
  }

  @override
  bool operator ==(Object other) => other is Monto && other.valor == valor;

  @override
  int get hashCode => valor.hashCode;
}
