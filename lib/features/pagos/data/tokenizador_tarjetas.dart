import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// La tarjeta no se pudo cambiar por un token. [campo] es `numero`,
/// `vencimiento` o `cvv`, para marcar el campo en el formulario.
class TarjetaInvalida implements Exception {
  const TarjetaInvalida(this.campo, this.mensaje);

  final String campo;
  final String mensaje;

  @override
  String toString() => 'TarjetaInvalida($campo)';
}

/// Lo que queda de la tarjeta después de tokenizarla: el token para Payments y
/// los últimos cuatro dígitos para mostrar. El número, la fecha y el CVV no
/// salen del dispositivo (ADR-009, RN-P1).
class TarjetaTokenizada {
  const TarjetaTokenizada(this.token, this.ultimosCuatro);

  final String token;
  final String ultimosCuatro;
}

/// Hace las veces del widget de la pasarela: cambia la tarjeta por un token en
/// el dispositivo. Una pasarela certificada lo reemplazaría con su SDK.
abstract interface class TokenizadorTarjetas {
  /// Lanza [TarjetaInvalida] si la tarjeta no es válida o no se acepta.
  Future<TarjetaTokenizada> tokenizar({
    required String numero,
    required String vencimiento,
    required String cvv,
  });
}

/// Tarjetas de prueba de la pasarela simulada (ADR-009, modificación del 20
/// de octubre de 2026).
abstract final class TarjetasDePrueba {
  /// Payments aprueba el pago.
  static const aprobada = '4242424242424242';

  /// Payments lo rechaza por fondos insuficientes.
  static const rechazada = '4000000000000002';

  /// La pasarela «no responde»: el pago queda en proceso y se concilia.
  static const sinRespuesta = '4000000000000119';

  static const prefijos = {
    aprobada: 'tok_sim_aprobada_',
    rechazada: 'tok_sim_rechazada_',
    sinRespuesta: 'tok_sim_error_',
  };
}

/// Tokenizador de la pasarela simulada. Valida la tarjeta como una pasarela
/// (Luhn, fecha y CVV) y solo acepta las tres tarjetas de prueba: cualquier
/// otra se rechaza aquí, sin enviarse a ningún lado.
class TokenizadorSimulado implements TokenizadorTarjetas {
  TokenizadorSimulado({DateTime Function()? ahora, Random? azar})
    : _ahora = ahora ?? DateTime.now,
      _azar = azar ?? Random.secure();

  final DateTime Function() _ahora;
  final Random _azar;

  @override
  Future<TarjetaTokenizada> tokenizar({
    required String numero,
    required String vencimiento,
    required String cvv,
  }) async {
    final digitos = soloDigitos(numero);
    if (digitos.length < 13 || digitos.length > 19 || !luhn(digitos)) {
      throw const TarjetaInvalida(
        'numero',
        'El número de tarjeta no es válido.',
      );
    }
    if (!_vigente(vencimiento)) {
      throw const TarjetaInvalida(
        'vencimiento',
        'Escribe una fecha vigente, por ejemplo 12/28.',
      );
    }
    if (!RegExp(r'^\d{3,4}$').hasMatch(cvv.trim())) {
      throw const TarjetaInvalida('cvv', 'El código tiene 3 o 4 dígitos.');
    }
    final prefijo = TarjetasDePrueba.prefijos[digitos];
    if (prefijo == null) {
      throw const TarjetaInvalida(
        'numero',
        'En modo de pruebas solo se aceptan las tarjetas de prueba.',
      );
    }
    final sufijo = List.generate(
      16,
      (_) => _azar.nextInt(16).toRadixString(16),
    ).join();
    return TarjetaTokenizada(
      '$prefijo$sufijo',
      digitos.substring(digitos.length - 4),
    );
  }

  bool _vigente(String texto) {
    final partes = RegExp(r'^(\d{2})\s*/\s*(\d{2})$').firstMatch(texto.trim());
    if (partes == null) return false;
    final mes = int.parse(partes.group(1)!);
    final anio = 2000 + int.parse(partes.group(2)!);
    if (mes < 1 || mes > 12) return false;
    final hoy = _ahora();
    return anio > hoy.year || (anio == hoy.year && mes >= hoy.month);
  }

  static String soloDigitos(String texto) =>
      texto.replaceAll(RegExp(r'\D'), '');

  /// Algoritmo de Luhn: detecta errores de digitación en el número.
  static bool luhn(String digitos) {
    var suma = 0;
    var doble = false;
    for (var i = digitos.length - 1; i >= 0; i--) {
      var d = int.parse(digitos[i]);
      if (doble) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      suma += d;
      doble = !doble;
    }
    return suma % 10 == 0;
  }
}

final tokenizadorTarjetasProvider = Provider<TokenizadorTarjetas>(
  (ref) => TokenizadorSimulado(),
);
