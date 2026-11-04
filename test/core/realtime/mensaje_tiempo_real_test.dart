import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/core/realtime/mensaje_tiempo_real.dart';

void main() {
  test('lee el mensaje de cambio de estado del DD 8.5', () {
    final m = MensajeTiempoReal.fromJson({
      'type': 'service-request.status-changed',
      'serviceRequestId': '9a7b',
      'status': 'en_progreso',
      'occurredAt': '2026-10-03T16:10:00Z',
    });
    expect(m.tipo, 'service-request.status-changed');
    expect(m.serviceRequestId, '9a7b');
    expect(m.status, 'en_progreso');
    expect(m.ocurridoEn, DateTime.utc(2026, 10, 3, 16, 10));
    expect(MensajeTiempoReal.intervaloRespaldo, const Duration(seconds: 30));
  });
}
