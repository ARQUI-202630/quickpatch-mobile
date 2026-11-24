import '../../core/solicitudes/seccion_detalle_solicitud.dart';
import '../../features/calificacion/presentation/widgets/calificacion_cliente.dart';
import '../../features/pagos/presentation/widgets/pago_cliente.dart';

/// Secciones que el detalle de la solicitud del cliente toma de otras features
/// (SCRUM-714). `app/` compone features; `solicitudes` no importa a `pagos` ni
/// a `calificacion` (features/README.md).
final List<SeccionDetalleSolicitud> seccionesDetalleSolicitud = [
  // El pago de una solicitud de empresa lo hace cualquier usuario de la empresa
  // (RN-P6, SCRUM-43), no solo quien la creó: también en solo lectura.
  (datos, alCambiar) => PagoCliente.aplica(datos.estado)
      ? PagoCliente(
          solicitudId: datos.solicitudId,
          estado: datos.estado,
          alCambiar: alCambiar,
        )
      : null,
  (datos, alCambiar) =>
      !datos.soloLectura && CalificacionCliente.aplica(datos.estado)
      ? CalificacionCliente(
          solicitudId: datos.solicitudId,
          calificacion: datos.calificacion,
          alCambiar: alCambiar,
        )
      : null,
];
