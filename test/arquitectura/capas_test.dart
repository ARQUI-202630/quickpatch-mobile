// Capas de la app (lib/features/README.md, SDD 10.3.1; SCRUM-714). Recorre lib/ y resuelve cada import y export
// relativo o `package:quickpatch_mobile/` a su ruta dentro de lib/, para revisar quién depende de quién:
//
// - una feature no importa otra feature;
// - core/ y shared/ no importan de features/;
// - core/ no importa de app/, y shared/ solo de app/theme (tokens y tema);
// - el domain/ de una feature no importa Flutter, HTTP, Riverpod ni su data/.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _paquete = 'package:quickpatch_mobile/';
final _directiva = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

/// Una dependencia de un archivo de lib/: `destino` es la ruta dentro de lib/ o el URI externo tal cual.
typedef _Dependencia = ({String origen, String destino});

List<_Dependencia> _dependencias() {
  final lib = Directory('lib');
  final resultado = <_Dependencia>[];
  for (final archivo
      in lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
    final origen = archivo.path
        .replaceAll(r'\', '/')
        .substring(lib.path.length + 1);
    for (final m in _directiva.allMatches(archivo.readAsStringSync())) {
      final uri = m.group(1)!;
      final String destino;
      if (uri.startsWith(_paquete)) {
        destino = uri.substring(_paquete.length);
      } else if (uri.contains(':')) {
        destino = uri;
      } else {
        destino = _normalizar('${_directorio(origen)}/$uri');
      }
      resultado.add((origen: origen, destino: destino));
    }
  }
  return resultado;
}

String _directorio(String ruta) =>
    ruta.contains('/') ? ruta.substring(0, ruta.lastIndexOf('/')) : '';

/// Resuelve `.` y `..` de una ruta con `/` (sin depender del paquete path).
String _normalizar(String ruta) {
  final partes = <String>[];
  for (final parte in ruta.split('/')) {
    if (parte.isEmpty || parte == '.') continue;
    if (parte == '..') {
      if (partes.isNotEmpty) partes.removeLast();
    } else {
      partes.add(parte);
    }
  }
  return partes.join('/');
}

String? _feature(String ruta) {
  final partes = ruta.split('/');
  return partes.length > 1 && partes.first == 'features' ? partes[1] : null;
}

void _sinViolaciones(Iterable<_Dependencia> violaciones, String regla) {
  final lista = violaciones.map((d) => '${d.origen} -> ${d.destino}').toList();
  expect(lista, isEmpty, reason: 'Viola $regla');
}

void main() {
  final dependencias = _dependencias();

  test('recorre el código de lib/', () {
    expect(dependencias.length, greaterThan(100));
  });

  test('una feature no importa otra feature', () {
    _sinViolaciones(
      dependencias.where((d) {
        final desde = _feature(d.origen);
        final hacia = _feature(d.destino);
        return desde != null && hacia != null && desde != hacia;
      }),
      'features/README.md: una feature no importa a otra',
    );
  });

  test('core/ y shared/ no importan de features/', () {
    _sinViolaciones(
      dependencias.where(
        (d) =>
            (d.origen.startsWith('core/') || d.origen.startsWith('shared/')) &&
            d.destino.startsWith('features/'),
      ),
      'features/README.md: core/ y shared/ no importan de features/',
    );
  });

  test('core/ no importa de app/, y shared/ solo de app/theme', () {
    _sinViolaciones(
      dependencias.where(
        (d) =>
            d.destino.startsWith('app/') &&
            (d.origen.startsWith('core/') ||
                (d.origen.startsWith('shared/') &&
                    !d.destino.startsWith('app/theme/'))),
      ),
      'features/README.md: ni core/ ni shared/ importan del resto de app/',
    );
  });

  test(
    'el domain/ de una feature no conoce Flutter, HTTP, Riverpod ni data/',
    () {
      final prohibidos = [
        'package:flutter/',
        'package:flutter_riverpod/',
        'package:riverpod/',
        'package:dio/',
        'package:http/',
        'package:go_router/',
      ];
      _sinViolaciones(
        dependencias.where((d) {
          final partes = d.origen.split('/');
          if (partes.length < 3 ||
              partes.first != 'features' ||
              partes[2] != 'domain') {
            return false;
          }
          final esData = d.destino.startsWith('features/${partes[1]}/data/');
          return esData || prohibidos.any(d.destino.startsWith);
        }),
        'features/README.md: domain/ sin dependencias de Flutter ni de HTTP',
      );
    },
  );
}
