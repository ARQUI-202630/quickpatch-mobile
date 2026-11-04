/// `Quote` de `service-request.v1.yaml` 1.6.0 para las pruebas de SCRUM-489.
Map<String, dynamic> cotizacionJson({
  int numero = 1,
  String estado = 'pendiente',
  String manoDeObra = '120000.00',
  String materiales = '65000.00',
  String total = '185000.00',
  String? detalle = 'Cambio de sifón y empaques.',
  String? motivo,
}) => {
  'id': 'q-$numero',
  'quoteNumber': numero,
  'status': estado,
  'laborAmount': manoDeObra,
  'materialsAmount': materiales,
  'totalAmount': total,
  'detail': detalle,
  'createdAt': '2026-10-20T15:00:00Z',
  'expiresAt': '2026-10-21T15:00:00Z',
  'respondedAt': estado == 'pendiente' ? null : '2026-10-20T16:00:00Z',
  'rejectionReason': motivo,
};
