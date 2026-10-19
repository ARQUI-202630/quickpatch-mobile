import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/geo/mapa_localidades.dart';
import '../../../../core/geo/repositorio_localidades.dart';
import '../../../../shared/widgets/mapa_bogota.dart';
import '../../domain/modelos.dart';

/// Pregunta «¿Es aquí?» antes de crear una solicitud sin GPS (SCRUM-457,
/// service-request 1.3.0). Muestra lo que reconoció el geocodificador, la
/// localidad y el punto en el mapa, porque la localidad decide qué técnicos
/// reciben la oferta (RN-M9). Devuelve `true` si el cliente confirma.
Future<bool> confirmarUbicacion(
  BuildContext context,
  VistaPreviaUbicacion vista,
) async {
  final confirmado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => ConfirmarUbicacion(vista: vista),
  );
  return confirmado ?? false;
}

class ConfirmarUbicacion extends ConsumerWidget {
  const ConfirmarUbicacion({super.key, required this.vista});

  final VistaPreviaUbicacion vista;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texto = Theme.of(context).textTheme;
    final secundario = texto.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    // Sin el asset del mapa, la dirección reconocida y la localidad bastan.
    final mapa = ref.watch(mapaLocalidadesProvider).value;
    final punto = MapaLocalidades.proyectar(
      vista.ubicacion.longitud,
      vista.ubicacion.latitud,
    );
    final codigo = vista.localidad.codigo;

    return SingleChildScrollView(
      key: const Key('confirmar-ubicacion'),
      padding: const EdgeInsets.fromLTRB(
        QpEspacio.pantalla,
        0,
        QpEspacio.pantalla,
        QpEspacio.e6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('¿Es aquí?', style: texto.titleLarge),
          ),
          const SizedBox(height: QpEspacio.e2),
          Text(
            vista.direccionReconocida,
            key: const Key('direccion-reconocida'),
            style: texto.titleMedium,
          ),
          const SizedBox(height: QpEspacio.e1),
          Text(
            'Localidad: ${vista.localidad.nombre}',
            key: const Key('localidad-reconocida'),
            style: secundario,
          ),
          const SizedBox(height: QpEspacio.e2),
          Text(
            'Ubicamos la calle o el barrio, no el número exacto. Con este '
            'punto buscamos técnicos que trabajen en esa localidad.',
            style: secundario,
          ),
          if (mapa != null) ...[
            const SizedBox(height: QpEspacio.e3),
            MapaBogota(
              key: const Key('mapa-confirmacion'),
              mapa: mapa,
              disponibles: mapa.codigos.toSet(),
              elegidas: {codigo},
              punto: punto,
              encuadreInicial: mapa.cajaDe(codigo)?.inflate(0.01),
              alto: 240,
            ),
          ],
          const SizedBox(height: QpEspacio.e4),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: QpEspacio.e2,
            runSpacing: QpEspacio.e2,
            children: [
              OutlinedButton(
                key: const Key('boton-no-es-aqui'),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No es aquí'),
              ),
              FilledButton(
                key: const Key('boton-si-es-aqui'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sí, es aquí'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
