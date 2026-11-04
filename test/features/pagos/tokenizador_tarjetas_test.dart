import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/features/pagos/data/tokenizador_tarjetas.dart';
import 'package:quickpatch_mobile/features/pagos/domain/pago.dart';

/// Tokenizador de la pasarela simulada (ADR-009 modificado, SCRUM-116): la
/// tarjeta se valida y se cambia por un token sin salir del dispositivo.
void main() {
  final tokenizador = TokenizadorSimulado(
    ahora: () => DateTime(2026, 10, 21),
    azar: Random(7),
  );

  Future<TarjetaTokenizada> tokenizar(
    String numero, {
    String vencimiento = '12/30',
    String cvv = '123',
  }) =>
      tokenizador.tokenizar(numero: numero, vencimiento: vencimiento, cvv: cvv);

  Matcher invalidaEn(String campo) =>
      throwsA(isA<TarjetaInvalida>().having((e) => e.campo, 'campo', campo));

  test('las tres tarjetas de prueba dan su token, sin el número', () async {
    final aprobada = await tokenizar('4242 4242 4242 4242');
    final rechazada = await tokenizar(TarjetasDePrueba.rechazada);
    final sinRespuesta = await tokenizar(TarjetasDePrueba.sinRespuesta);

    expect(aprobada.token, startsWith('tok_sim_aprobada_'));
    expect(aprobada.token, isNot(contains('4242424242424242')));
    expect(aprobada.token.length, 'tok_sim_aprobada_'.length + 16);
    expect(aprobada.ultimosCuatro, '4242');
    expect(rechazada.token, startsWith('tok_sim_rechazada_'));
    expect(sinRespuesta.token, startsWith('tok_sim_error_'));
    expect(sinRespuesta.ultimosCuatro, '0119');
  });

  test('número inválido por Luhn o por longitud', () {
    expect(() => tokenizar('4242424242424241'), invalidaEn('numero'));
    expect(() => tokenizar('4242'), invalidaEn('numero'));
  });

  test('una tarjeta válida que no es de prueba no se acepta', () {
    expect(
      () => tokenizar('5555555555554444'),
      throwsA(
        isA<TarjetaInvalida>().having(
          (e) => e.mensaje,
          'mensaje',
          contains('tarjetas de prueba'),
        ),
      ),
    );
  });

  test('vencimiento con formato, mes y vigencia', () {
    expect(
      () => tokenizar(TarjetasDePrueba.aprobada, vencimiento: '1230'),
      invalidaEn('vencimiento'),
    );
    expect(
      () => tokenizar(TarjetasDePrueba.aprobada, vencimiento: '13/30'),
      invalidaEn('vencimiento'),
    );
    expect(
      () => tokenizar(TarjetasDePrueba.aprobada, vencimiento: '09/26'),
      invalidaEn('vencimiento'),
    );
    expect(
      tokenizar(TarjetasDePrueba.aprobada, vencimiento: '10/26'),
      completes,
    );
  });

  test('CVV de 3 o 4 dígitos', () {
    expect(
      () => tokenizar(TarjetasDePrueba.aprobada, cvv: '12'),
      invalidaEn('cvv'),
    );
    expect(
      () => tokenizar(TarjetasDePrueba.aprobada, cvv: 'abc'),
      invalidaEn('cvv'),
    );
    expect(tokenizar(TarjetasDePrueba.aprobada, cvv: '1234'), completes);
    expect(
      const TarjetaInvalida('cvv', 'x').toString(),
      'TarjetaInvalida(cvv)',
    );
  });

  test('el pago se lee según el contrato y explica el rechazo', () {
    final pago = Pago.desdeJson({
      'paymentId': 'p-1',
      'serviceRequestId': 's-1',
      'status': 'rechazado',
      'amount': '185000.00',
      'reasonCode': 'fondos_insuficientes',
      'invoiceId': null,
      'createdAt': '2026-10-21T15:00:00Z',
      'processedAt': '2026-10-21T15:01:00Z',
    });

    expect(pago.estado, EstadoPago.rechazado);
    expect(pago.sePuedePagar, isTrue);
    expect(pago.monto.formatear(), r'$ 185.000');
    expect(pago.procesadoEn, DateTime.utc(2026, 10, 21, 15, 1));
    expect(pago.motivoLegible, contains('fondos'));
    for (final (motivo, texto) in [
      ('pasarela_sin_respuesta', 'no respondió'),
      ('token_invalido', 'no reconoció'),
      ('otro', 'rechazó'),
    ]) {
      final otro = Pago(
        id: 'p',
        solicitudId: 's',
        estado: EstadoPago.rechazado,
        monto: pago.monto,
        creadoEn: pago.creadoEn,
        motivo: motivo,
      );
      expect(otro.motivoLegible, contains(texto));
    }
    expect(() => EstadoPago.desdeValor('raro'), throwsFormatException);
    expect(
      const DatosFacturacion(
        nombre: ' Ana ',
        tipoDocumento: TipoDocumento.nit,
        numeroDocumento: ' 900123456 ',
        correo: ' a@b.co ',
      ).toJson(),
      {
        'name': 'Ana',
        'documentType': 'NIT',
        'documentNumber': '900123456',
        'email': 'a@b.co',
      },
    );
  });
}
