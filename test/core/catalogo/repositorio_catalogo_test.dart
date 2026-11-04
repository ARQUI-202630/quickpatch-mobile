import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/core/catalogo/repositorio_catalogo.dart';
import 'package:quickpatch_mobile/core/errors/app_exception.dart';
import 'package:quickpatch_mobile/core/network/api_endpoints.dart';

import '../../helpers/fakes.dart';

/// Catálogo de categorías (`GET /v1/service-requests/categories`, service-request.v1.yaml 1.8.0, ADR-025).
void main() {
  late AdaptadorFalso adaptador;
  late RepositorioCatalogo repositorio;

  setUp(() {
    adaptador = AdaptadorFalso(
      (_) => respuestaJson([
        {'id': 'c-1', 'name': 'Plomería', 'description': 'Fugas y tuberías'},
        {'id': 'c-2', 'name': 'Electricidad'},
      ], 200),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://gw/api'))
      ..httpClientAdapter = adaptador;
    repositorio = RepositorioCatalogo(dio);
  });

  test('lee las categorías del tenant de la sesión', () async {
    final categorias = await repositorio.categorias();
    expect(adaptador.ultima!.path, ApiEndpoints.categorias);
    expect(categorias.map((c) => c.nombre), ['Plomería', 'Electricidad']);
    expect(categorias.first.descripcion, 'Fugas y tuberías');
    expect(categorias.last.descripcion, isNull);
  });

  test('sin sesión pide las categorías del canal', () async {
    final categorias = await repositorio.categoriasPublicas();
    expect(adaptador.ultima!.path, ApiEndpoints.categorias);
    expect(categorias, hasLength(2));
  });

  test('traduce los errores a AppException', () async {
    adaptador.responder = (_) => respuestaJson(<String, dynamic>{}, 503);
    await expectLater(
      repositorio.categorias(),
      throwsA(isA<AppException>().having((e) => e.status, 'status', 503)),
    );
  });
}
