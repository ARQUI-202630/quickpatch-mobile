import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_exception.dart';
import '../network/api_endpoints.dart';
import '../network/cliente_api.dart';
import '../network/politica_reintento.dart';
import '../session/controlador_sesion.dart';
import '../session/rol_usuario.dart';

/// Roles con buzón en la app (`communication.v1.yaml` 1.0.0). El proveedor
/// recibe 403; el `admin_tenant` lo tendrá en el panel web.
bool tieneBuzon(RolUsuario rol) => switch (rol) {
  RolUsuario.cliente ||
  RolUsuario.empresaContacto ||
  RolUsuario.tecnico => true,
  _ => false,
};

/// Notificaciones sin leer del usuario de la sesión (`unreadCount` de
/// `GET /v1/notifications`), para la campana del inicio y la fila de Cuenta
/// (SCRUM-459). Es 0 para los roles sin buzón, sin consultar.
///
/// El shell lo vuelve a consultar con cada aviso del canal en tiempo real y,
/// si el canal no está conectado, cada 30 s (`EscuchaNotificaciones`).
final contadorNotificacionesProvider = FutureProvider.autoDispose<int>(
  (ref) async {
    final rol = ref.watch(controladorSesionProvider).value?.usuario.rol;
    if (rol == null || !tieneBuzon(rol)) return 0;

    try {
      final respuesta = await ref
          .watch(clienteApiProvider)
          .get<Map<String, dynamic>>(
            ApiEndpoints.notificaciones,
            queryParameters: {'unread': true, 'size': 1},
          );
      return respuesta.data!['unreadCount'] as int;
    } on DioException catch (e) {
      throw AppException.desdeDio(e);
    }
  },
  // La misma regla de main.dart, también donde el contenedor no la tenga.
  retry: politicaReintento,
);
