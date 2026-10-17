import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/utils/fechas.dart';
import '../../../../shared/widgets/icono_categoria.dart';
import '../../domain/modelos.dart';
import 'chip_estado.dart';

/// Resumen de una solicitud en una lista: servicio, estado, descripción,
/// dirección (si la lista la trae) y fecha, con acciones opcionales al pie (por ejemplo, aceptar o
/// rechazar una oferta en SCRUM-30). Recibe los datos sueltos para servir
/// tanto a la solicitud del cliente como a la oferta del técnico.
class TarjetaSolicitud extends StatelessWidget {
  const TarjetaSolicitud({
    required this.servicio,
    required this.descripcion,
    this.direccion,
    this.estado,
    this.fecha,
    this.alTocar,
    this.acciones = const [],
    super.key,
  });

  /// Tarjeta de una [Solicitud]; [servicio] es el nombre de su categoría, si
  /// la pantalla ya lo tiene.
  factory TarjetaSolicitud.de(
    Solicitud solicitud, {
    String? servicio,
    VoidCallback? alTocar,
    List<Widget> acciones = const [],
    Key? key,
  }) => TarjetaSolicitud(
    key: key,
    servicio: servicio ?? 'Solicitud de servicio',
    descripcion: solicitud.descripcion,
    direccion: solicitud.direccion,
    estado: solicitud.estado,
    fecha: solicitud.creadaEn,
    alTocar: alTocar,
    acciones: acciones,
  );

  final String servicio;
  final String descripcion;
  final String? direccion;
  final EstadoSolicitud? estado;
  final DateTime? fecha;
  final VoidCallback? alTocar;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    final secundario = texto.bodySmall?.copyWith(
      color: esquema.onSurfaceVariant,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.all(QpEspacio.e4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: esquema.primaryContainer,
                      borderRadius: BorderRadius.circular(QpRadio.sm),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(QpEspacio.e2),
                      child: Icon(
                        iconoCategoria(servicio),
                        size: 20,
                        color: esquema.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: QpEspacio.e3),
                  Expanded(child: Text(servicio, style: texto.titleSmall)),
                  if (estado != null) ...[
                    const SizedBox(width: QpEspacio.e2),
                    Flexible(child: ChipEstado(estado!)),
                  ],
                ],
              ),
              const SizedBox(height: QpEspacio.e3),
              Text(
                descripcion,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: texto.bodyMedium,
              ),
              const SizedBox(height: QpEspacio.e3),
              if (direccion case final direccion?) ...[
                _Dato(Icons.place_outlined, direccion, secundario),
                const SizedBox(height: QpEspacio.e1),
              ],
              if (fecha != null) ...[
                _Dato(
                  Icons.schedule_rounded,
                  fechaRelativa(fecha!.toLocal(), DateTime.now()),
                  secundario,
                ),
              ],
              if (acciones.isNotEmpty) ...[
                const SizedBox(height: QpEspacio.e4),
                Wrap(
                  spacing: QpEspacio.e2,
                  runSpacing: QpEspacio.e2,
                  alignment: WrapAlignment.end,
                  children: acciones,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.icono, this.texto, this.estilo);

  final IconData icono;
  final String texto;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icono, size: 16, color: estilo?.color),
      const SizedBox(width: QpEspacio.e1),
      Expanded(child: Text(texto, style: estilo)),
    ],
  );
}
