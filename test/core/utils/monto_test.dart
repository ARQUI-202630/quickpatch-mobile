import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/core/utils/monto.dart';

void main() {
  test('formatea pesos sin usar punto flotante', () {
    expect(Monto('185000.00').formatear(), r'$ 185.000');
    expect(Monto('1250.50').formatear(), r'$ 1.250,50');
    expect(Monto('0.99').formatear(), r'$ 0,99');
    expect(Monto('1234567890.00').formatear(), r'$ 1.234.567.890');
  });

  test('rechaza montos fuera del formato del contrato', () {
    expect(() => Monto('185000'), throwsFormatException);
    expect(() => Monto('18,5'), throwsFormatException);
    expect(() => Monto('-1.00'), throwsFormatException);
  });

  test('igualdad por valor', () {
    expect(Monto('10.00'), Monto('10.00'));
    expect(Monto('10.00').hashCode, Monto('10.00').hashCode);
    expect(Monto('10.00') == Monto('10.01'), isFalse);
  });
}
