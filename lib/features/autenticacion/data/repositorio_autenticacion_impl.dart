import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/cliente_api.dart';
import '../../../core/session/sesion.dart';
import '../domain/datos_registro.dart';
import '../domain/repositorio_autenticacion.dart';
import 'autenticacion_api.dart';

class RepositorioAutenticacionImpl implements RepositorioAutenticacion {
  RepositorioAutenticacionImpl(this._api, {DateTime Function()? reloj})
    : _reloj = reloj ?? DateTime.now;

  final AutenticacionApi _api;
  final DateTime Function() _reloj;

  @override
  Future<Sesion> iniciarSesion({
    required String email,
    required String password,
  }) async {
    try {
      final json = await _api.iniciarSesion(email.trim(), password);
      return Sesion.desdeLogin(json, _reloj());
    } on DioException catch (e) {
      throw AppException.desdeDio(e);
    }
  }

  @override
  Future<void> registrar(DatosRegistro datos) async {
    try {
      final json = datos.toJson();
      await switch (datos.tipo) {
        TipoCuenta.hogar => _api.registrarCliente(json),
        TipoCuenta.empresa => _api.registrarEmpresa(json),
      };
    } on DioException catch (e) {
      throw AppException.desdeDio(e);
    }
  }
}

final repositorioAutenticacionProvider = Provider<RepositorioAutenticacion>(
  (ref) => RepositorioAutenticacionImpl(
    AutenticacionApi(ref.watch(clienteApiProvider)),
  ),
);
