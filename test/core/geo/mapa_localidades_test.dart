import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/core/geo/mapa_localidades.dart';
import 'package:quickpatch_mobile/core/geo/repositorio_localidades.dart';

/// SCRUM-89: límites de las localidades para el mapa de cobertura.
void main() {
  late MapaLocalidades mapa;

  setUpAll(() {
    mapa = MapaLocalidades.desdeGeoJson(
      File(rutaMapaLocalidades).readAsStringSync(),
    );
  });

  String? en(double longitud, double latitud) =>
      mapa.localidadEn(MapaLocalidades.proyectar(longitud, latitud));

  test('el asset trae las 20 localidades con los códigos de Matching', () {
    expect(mapa.codigos.toList()..sort(), [
      for (var i = 1; i <= 20; i++) i.toString().padLeft(2, '0'),
    ]);
  });

  test('encuentra la localidad de lugares conocidos', () {
    expect(en(-74.0480, 4.6765), '02', reason: 'Parque de la 93: Chapinero');
    expect(en(-74.0306, 4.6950), '01', reason: 'Plaza de Usaquén');
    expect(en(-74.1469, 4.7016), '09', reason: 'Aeropuerto: Fontibón');
    expect(en(-74.0640, 4.6230), '03', reason: 'Parque Nacional: Santa Fe');
    expect(en(-74.2000, 4.1000), '20', reason: 'Sumapaz');
    expect(en(-73.5000, 4.6000), isNull, reason: 'fuera de Bogotá');
  });

  test('La Candelaria es un hueco de Santa Fe y no cuenta como Santa Fe', () {
    expect(en(-74.0760, 4.5981), '17', reason: 'Plaza de Bolívar');
  });

  test('el encuadre urbano deja fuera la zona rural y la ciudad la incluye', () {
    final sumapaz = MapaLocalidades.proyectar(-74.2, 4.1);
    expect(mapa.limites.contains(sumapaz), isTrue);
    expect(mapa.limitesUrbanos.contains(sumapaz), isFalse);
    expect(
      mapa.limitesUrbanos.contains(MapaLocalidades.proyectar(-74.0480, 4.6765)),
      isTrue,
    );
    // Incluye el casco urbano de Usme y Ciudad Bolívar, pero no su zona rural.
    expect(en(-74.1110, 4.4880), '05', reason: 'Usme pueblo');
    expect(
      mapa.limitesUrbanos.contains(MapaLocalidades.proyectar(-74.1110, 4.4880)),
      isTrue,
    );
    expect(
      mapa.limitesUrbanos.contains(MapaLocalidades.proyectar(-74.15, 4.40)),
      isFalse,
    );
    expect(mapa.limitesUrbanos.height, lessThan(mapa.limites.height / 2));
    // El ancho también es el del casco urbano: Sumapaz llega más al occidente.
    expect(mapa.limitesUrbanos.left, greaterThan(mapa.limites.left));
    expect(
      mapa.limitesUrbanos.contains(MapaLocalidades.proyectar(-74.30, 4.60)),
      isFalse,
    );
  });

  test('el norte queda arriba y el este a la derecha', () {
    final norte = MapaLocalidades.proyectar(-74.05, 4.7);
    final sur = MapaLocalidades.proyectar(-74.05, 4.5);
    final este = MapaLocalidades.proyectar(-74.0, 4.6);
    final oeste = MapaLocalidades.proyectar(-74.1, 4.6);
    expect(norte.dy, lessThan(sur.dy));
    expect(este.dx, greaterThan(oeste.dx));
  });

  test(
    'lee MultiPolygon y rechaza geometrías desconocidas o un mapa vacío',
    () {
      const multi = '''
{"type":"FeatureCollection","features":[{"type":"Feature","properties":{"codigo":"01"},
 "geometry":{"type":"MultiPolygon","coordinates":[
  [[[0,0],[1,0],[1,1],[0,1],[0,0]]],
  [[[2,0],[3,0],[3,1],[2,1],[2,0]]]]}}]}''';
      final dos = MapaLocalidades.desdeGeoJson(multi);
      expect(dos.anillos['01'], hasLength(2));
      expect(dos.localidadEn(MapaLocalidades.proyectar(2.5, 0.5)), '01');
      expect(dos.localidadEn(MapaLocalidades.proyectar(1.5, 0.5)), isNull);
      // Si el mapa no llega a la zona rural, el encuadre urbano es el mapa.
      expect(dos.limitesUrbanos, dos.limites);

      expect(
        () => MapaLocalidades.desdeGeoJson(
          '{"features":[{"properties":{"codigo":"01"},'
          '"geometry":{"type":"Point","coordinates":[0,0]}}]}',
        ),
        throwsFormatException,
      );
      expect(
        () => MapaLocalidades.desdeGeoJson('{"features":[]}'),
        throwsFormatException,
      );
    },
  );
}
