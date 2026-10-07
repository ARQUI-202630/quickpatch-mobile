import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickpatch_mobile/features/solicitudes/data/proveedor_ubicacion.dart';

final _ahora = DateTime(2026, 10, 7, 12);

Position _posicion({DateTime? cuando, double latitud = 4.6533}) => Position(
  latitude: latitud,
  longitude: -74.0836,
  timestamp: cuando ?? _ahora,
  accuracy: 5,
  altitude: 2600,
  altitudeAccuracy: 1,
  heading: 0,
  headingAccuracy: 1,
  speed: 0,
  speedAccuracy: 1,
);

void main() {
  test('usa el proveedor por defecto si responde', () async {
    final llamadas = <bool>[];
    final p = await leerConRespaldo(
      LecturasGps(
        actual: ({bool soloGpsDelSistema = false}) async {
          llamadas.add(soloGpsDelSistema);
          return _posicion();
        },
        ultimaConocida: () async => fail('no debe consultarse'),
        ahora: () => _ahora,
      ),
    );

    expect(p.latitude, 4.6533);
    expect(llamadas, [false]);
  });

  test(
    'si el proveedor de Google falla, usa la última posición reciente',
    () async {
      final llamadas = <bool>[];
      final p = await leerConRespaldo(
        LecturasGps(
          actual: ({bool soloGpsDelSistema = false}) async {
            llamadas.add(soloGpsDelSistema);
            throw const LocationServiceDisabledException();
          },
          ultimaConocida: () async => _posicion(
            cuando: _ahora.subtract(const Duration(minutes: 2)),
            latitud: 4.70,
          ),
          ahora: () => _ahora,
        ),
      );

      expect(p.latitude, 4.70);
      expect(llamadas, [false]);
    },
  );

  test(
    'si la última es vieja o no hay, pide una lectura al GPS del sistema',
    () async {
      for (final ultima in [
        _posicion(cuando: _ahora.subtract(const Duration(hours: 1))),
        null,
      ]) {
        final llamadas = <bool>[];
        final p = await leerConRespaldo(
          LecturasGps(
            actual: ({bool soloGpsDelSistema = false}) async {
              llamadas.add(soloGpsDelSistema);
              if (!soloGpsDelSistema)
                throw Exception('sin servicios de Google');
              return _posicion(latitud: 4.61);
            },
            ultimaConocida: () async => ultima,
            ahora: () => _ahora,
          ),
        );

        expect(p.latitude, 4.61);
        expect(llamadas, [false, true]);
      }
    },
  );

  test('si todo falla, lanza un mensaje para el usuario', () async {
    await expectLater(
      leerConRespaldo(
        LecturasGps(
          actual: ({bool soloGpsDelSistema = false}) async =>
              throw Exception('sin GPS'),
          ultimaConocida: () async => null,
          ahora: () => _ahora,
        ),
      ),
      throwsA(
        isA<UbicacionNoDisponible>().having(
          (e) => e.mensaje,
          'mensaje',
          contains('No pudimos obtener tu ubicación'),
        ),
      ),
    );
  });
}
