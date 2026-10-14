import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

/// Límites de las localidades de Bogotá D.C. para el mapa de cobertura
/// (SCRUM-89). Vienen de `assets/geo/localidades_bogota.geojson` (capa
/// «Localidad» de la SDP publicada por IDECA, CC BY 4.0) y se proyectan a un
/// plano: x = longitud · cos 4.6°, y = −latitud, así el norte queda arriba y
/// las distancias no se deforman a la latitud de Bogotá.
class MapaLocalidades {
  MapaLocalidades._(
    this.anillos,
    this._cajas,
    this.limites,
    this.limitesUrbanos,
  );

  /// Lee el GeoJSON (`Polygon` o `MultiPolygon` con la propiedad `codigo`).
  factory MapaLocalidades.desdeGeoJson(String texto) {
    final json = jsonDecode(texto) as Map<String, dynamic>;
    final anillos = <String, List<List<Offset>>>{};
    for (final elemento
        in (json['features'] as List).cast<Map<String, dynamic>>()) {
      final codigo = (elemento['properties'] as Map)['codigo'] as String;
      final geometria = elemento['geometry'] as Map<String, dynamic>;
      final poligonos = switch (geometria['type']) {
        'Polygon' => [geometria['coordinates'] as List<dynamic>],
        'MultiPolygon' =>
          (geometria['coordinates'] as List).cast<List<dynamic>>(),
        final tipo => throw FormatException('Geometría no soportada: $tipo'),
      };
      anillos[codigo] = [
        for (final poligono in poligonos)
          for (final anillo in poligono.cast<List<dynamic>>())
            [
              for (final punto in anillo.cast<List<dynamic>>())
                _proyectar(punto),
            ],
      ];
    }
    if (anillos.isEmpty) {
      throw const FormatException('El mapa no tiene localidades.');
    }
    final cajas = {
      for (final MapEntry(:key, :value) in anillos.entries)
        key: _caja(value.expand((anillo) => anillo)),
    };
    final limites = cajas.values.reduce((a, b) => a.expandToInclude(b));
    // Solo los puntos al norte del borde urbano: Sumapaz se extiende mucho
    // más al occidente que el casco urbano y lo correría a un lado.
    final sur = proyectar(0, latitudSurUrbana).dy;
    final urbanos = [
      for (final lista in anillos.values)
        for (final anillo in lista)
          for (final p in anillo)
            if (p.dy <= sur) p,
    ];
    return MapaLocalidades._(
      anillos,
      cajas,
      limites,
      urbanos.isEmpty ? limites : _caja(urbanos),
    );
  }

  /// Borde sur del casco urbano: más al sur solo hay zona rural (todo
  /// Sumapaz y el sur de Usme y Ciudad Bolívar), que ocupa casi dos tercios del
  /// mapa. El encuadre urbano llega hasta aquí para que las localidades del
  /// centro no queden diminutas.
  static const latitudSurUrbana = 4.47;

  static final double _coseno = math.cos(4.6 * math.pi / 180);

  /// Anillos proyectados de cada localidad, por código. Un anillo dentro de
  /// otro es un hueco: el segundo anillo de Santa Fe es La Candelaria.
  final Map<String, List<List<Offset>>> anillos;
  final Map<String, Rect> _cajas;

  /// Rectángulo de toda la ciudad, en coordenadas proyectadas.
  final Rect limites;

  /// Rectángulo de la ciudad hasta [latitudSurUrbana].
  final Rect limitesUrbanos;

  Iterable<String> get codigos => anillos.keys;

  /// Código de la localidad que contiene [punto] (en coordenadas proyectadas),
  /// o `null` si cae fuera. Usa la regla par-impar, así un punto en un hueco
  /// queda fuera de la localidad que lo rodea.
  String? localidadEn(Offset punto) {
    for (final MapEntry(:key, :value) in anillos.entries) {
      if (_cajas[key]!.contains(punto) && _dentro(punto, value)) {
        return key;
      }
    }
    return null;
  }

  /// Proyecta una coordenada (longitud, latitud) al plano del mapa.
  static Offset proyectar(double longitud, double latitud) =>
      Offset(longitud * _coseno, -latitud);

  static Offset _proyectar(List<dynamic> punto) =>
      proyectar((punto[0] as num).toDouble(), (punto[1] as num).toDouble());

  static Rect _caja(Iterable<Offset> puntos) {
    var izquierda = double.infinity, arriba = double.infinity;
    var derecha = double.negativeInfinity, abajo = double.negativeInfinity;
    for (final p in puntos) {
      izquierda = math.min(izquierda, p.dx);
      arriba = math.min(arriba, p.dy);
      derecha = math.max(derecha, p.dx);
      abajo = math.max(abajo, p.dy);
    }
    return Rect.fromLTRB(izquierda, arriba, derecha, abajo);
  }

  /// Rayo horizontal hacia la derecha: dentro si cruza un número impar de
  /// lados, contando los de todos los anillos.
  static bool _dentro(Offset punto, List<List<Offset>> anillos) {
    var dentro = false;
    for (final anillo in anillos) {
      for (var i = 0, j = anillo.length - 1; i < anillo.length; j = i++) {
        final a = anillo[i], b = anillo[j];
        if ((a.dy > punto.dy) != (b.dy > punto.dy) &&
            punto.dx <
                (b.dx - a.dx) * (punto.dy - a.dy) / (b.dy - a.dy) + a.dx) {
          dentro = !dentro;
        }
      }
    }
    return dentro;
  }
}
