import 'package:flutter/material.dart';

/// Tokens de diseño de QUICKPATCH (SCRUM-440).
///
/// Es la misma paleta del panel web (`quickpatch-web/src/styles/_tokens.scss`),
/// convertida de OKLCH a sRGB. Las pantallas no usan estos colores directamente:
/// leen `Theme.of(context).colorScheme` y `context.estados`, para que un cambio
/// de paleta o el tema oscuro no obliguen a tocarlas.
abstract final class QpColores {
  // Azul de marca: #00468C es azul700.
  static const azul50 = Color(0xFFF1F7FF);
  static const azul100 = Color(0xFFE2EEFF);
  static const azul200 = Color(0xFFC4DDFE);
  static const azul300 = Color(0xFF96C1F7);
  static const azul400 = Color(0xFF5E9BE7);
  static const azul500 = Color(0xFF2C77D0);
  static const azul600 = Color(0xFF0D5CAF);
  static const azul700 = Color(0xFF00468C);
  static const azul800 = Color(0xFF033469);
  static const azul900 = Color(0xFF052447);
  static const azul950 = Color(0xFF05162C);

  // Neutros con un leve matiz azul.
  static const neutro0 = Color(0xFFFFFFFF);
  static const neutro25 = Color(0xFFF7FAFF);
  static const neutro50 = Color(0xFFF2F5FB);
  static const neutro100 = Color(0xFFE8EBF1);
  static const neutro200 = Color(0xFFDADEE3);
  static const neutro300 = Color(0xFFC7CBD0);
  static const neutro400 = Color(0xFFA1A5AA);
  static const neutro500 = Color(0xFF777B7F);
  static const neutro600 = Color(0xFF5B5E62);
  static const neutro700 = Color(0xFF424549);
  static const neutro800 = Color(0xFF2B2E32);
  static const neutro850 = Color(0xFF1F2226);
  static const neutro900 = Color(0xFF181B1E);
  static const neutro950 = Color(0xFF101316);

  // Estados: el 700 es texto sobre el 50; el 200 es texto sobre fondos oscuros.
  static const verde50 = Color(0xFFE4F8E7);
  static const verde200 = Color(0xFF9EE0AE);
  static const verde700 = Color(0xFF21763C);
  static const verde900 = Color(0xFF0E3A1D);
  static const ambar50 = Color(0xFFFEF0D4);
  static const ambar200 = Color(0xFFF5CD7E);
  static const ambar700 = Color(0xFF915B02);
  static const ambar900 = Color(0xFF452B00);
  static const rojo50 = Color(0xFFFFEDEC);
  static const rojo200 = Color(0xFFFFB4AE);
  static const rojo700 = Color(0xFFB02A2D);
  static const rojo900 = Color(0xFF5C0F12);
}

/// Escala de espaciado de 4 px.
abstract final class QpEspacio {
  static const e1 = 4.0;
  static const e2 = 8.0;
  static const e3 = 12.0;
  static const e4 = 16.0;
  static const e5 = 20.0;
  static const e6 = 24.0;
  static const e8 = 32.0;
  static const e10 = 40.0;
  static const e12 = 48.0;

  /// Margen lateral de las pantallas.
  static const pantalla = e5;
}

abstract final class QpRadio {
  /// Chips e insignias pequeñas.
  static const sm = 8.0;

  /// Campos y botones.
  static const md = 12.0;

  /// Tarjetas y hojas inferiores.
  static const lg = 16.0;
  static const pildora = 999.0;
}

/// Alto mínimo de botones y campos (área táctil de 48 px, WCAG 2.5.8).
const qpAltoControl = 48.0;

/// Colores de estado (éxito, aviso, peligro e información) que Material 3 no
/// trae: cada uno con su fondo, para insignias y alertas.
@immutable
class QpEstados extends ThemeExtension<QpEstados> {
  const QpEstados({
    required this.exito,
    required this.exitoFondo,
    required this.aviso,
    required this.avisoFondo,
    required this.peligro,
    required this.peligroFondo,
    required this.info,
    required this.infoFondo,
  });

  static const claro = QpEstados(
    exito: QpColores.verde700,
    exitoFondo: QpColores.verde50,
    aviso: QpColores.ambar700,
    avisoFondo: QpColores.ambar50,
    peligro: QpColores.rojo700,
    peligroFondo: QpColores.rojo50,
    info: QpColores.azul700,
    infoFondo: QpColores.azul50,
  );

  static const oscuro = QpEstados(
    exito: QpColores.verde200,
    exitoFondo: QpColores.verde900,
    aviso: QpColores.ambar200,
    avisoFondo: QpColores.ambar900,
    peligro: QpColores.rojo200,
    peligroFondo: QpColores.rojo900,
    info: QpColores.azul200,
    infoFondo: QpColores.azul900,
  );

  final Color exito;
  final Color exitoFondo;
  final Color aviso;
  final Color avisoFondo;
  final Color peligro;
  final Color peligroFondo;
  final Color info;
  final Color infoFondo;

  @override
  QpEstados copyWith({
    Color? exito,
    Color? exitoFondo,
    Color? aviso,
    Color? avisoFondo,
    Color? peligro,
    Color? peligroFondo,
    Color? info,
    Color? infoFondo,
  }) => QpEstados(
    exito: exito ?? this.exito,
    exitoFondo: exitoFondo ?? this.exitoFondo,
    aviso: aviso ?? this.aviso,
    avisoFondo: avisoFondo ?? this.avisoFondo,
    peligro: peligro ?? this.peligro,
    peligroFondo: peligroFondo ?? this.peligroFondo,
    info: info ?? this.info,
    infoFondo: infoFondo ?? this.infoFondo,
  );

  @override
  QpEstados lerp(QpEstados? other, double t) {
    if (other == null) return this;
    return QpEstados(
      exito: Color.lerp(exito, other.exito, t)!,
      exitoFondo: Color.lerp(exitoFondo, other.exitoFondo, t)!,
      aviso: Color.lerp(aviso, other.aviso, t)!,
      avisoFondo: Color.lerp(avisoFondo, other.avisoFondo, t)!,
      peligro: Color.lerp(peligro, other.peligro, t)!,
      peligroFondo: Color.lerp(peligroFondo, other.peligroFondo, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoFondo: Color.lerp(infoFondo, other.infoFondo, t)!,
    );
  }
}

extension QpTemaContexto on BuildContext {
  /// Colores de estado del tema actual (claro u oscuro).
  QpEstados get estados =>
      Theme.of(this).extension<QpEstados>() ?? QpEstados.claro;
}
