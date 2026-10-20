import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/catalogo/repositorio_catalogo.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/geo/mapa_localidades.dart';
import '../../../../core/geo/repositorio_localidades.dart';
import '../../../../shared/widgets/icono_categoria.dart';
import '../../../../shared/widgets/mapa_bogota.dart';
import '../../../../shared/widgets/vista_error.dart';
import '../../../../shared/widgets/vista_estado.dart';
import '../../data/repositorio_solicitudes.dart';
import '../../domain/modelos.dart';
import '../widgets/chip_estado.dart';
import '../widgets/cotizacion_tecnico.dart';

/// Detalle de la solicitud asignada, para el técnico (RF-14, SCRUM-34 /
/// SCRUM-92). Contrato: `GET /v1/service-requests/{id}` (service-request
/// 1.1.0). El técnico asignado recibe la dirección, la ubicación y el contacto
/// del cliente solo entre `asignado` y `completado` (RN-SR13). Fuera de ese
/// rango la API responde 403; si la solicitud no es suya, 404.
///
/// La ubicación se ve sobre el mapa de localidades de la app, sin mapa de
/// fondo (R5). Para usar su app de mapas, el técnico copia la dirección: la
/// app no se la pasa a un tercero (K12). En `asignado` el técnico cotiza
/// (SCRUM-489, 1.6.0). Iniciar el servicio requiere la cotización aceptada
/// (DD 7.4) y todavía no tiene contrato.
class SolicitudAsignadaPage extends ConsumerWidget {
  const SolicitudAsignadaPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitud = ref.watch(solicitudProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Servicio asignado')),
      body: SafeArea(
        child: solicitud.when(
          loading: () => const IndicadorCarga(etiqueta: 'Cargando el servicio'),
          error: (e, _) =>
              Center(child: SingleChildScrollView(child: _Error(e, id))),
          data: (s) => RefreshIndicator(
            onRefresh: () {
              ref.invalidate(cotizacionesProvider(id));
              return ref.refresh(solicitudProvider(id).future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                QpEspacio.pantalla,
                QpEspacio.e2,
                QpEspacio.pantalla,
                QpEspacio.e8,
              ),
              children: [
                _Encabezado(s),
                const SizedBox(height: QpEspacio.e4),
                _Cliente(s.cliente),
                const SizedBox(height: QpEspacio.e4),
                _Seccion(
                  titulo: 'Qué pasa',
                  child: Text(s.descripcion, key: const Key('descripcion')),
                ),
                const SizedBox(height: QpEspacio.e4),
                _Ubicacion(s),
                if (CotizacionTecnico.aplica(s.estado)) ...[
                  const SizedBox(height: QpEspacio.e4),
                  CotizacionTecnico(
                    solicitud: s,
                    alCambiar: () => ref
                      ..invalidate(solicitudProvider(id))
                      ..invalidate(cotizacionesProvider(id)),
                  ),
                ],
                const SizedBox(height: QpEspacio.e6),
                _IniciarServicio(s.estado),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 403: el técnico ya no puede ver los datos (fuera de `asignado`–`completado`,
/// RN-SR13); 404: no es suya o no existe. El resto se puede reintentar.
class _Error extends ConsumerWidget {
  const _Error(this.error, this.id);

  final Object error;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = error;
    if (e is AppException && e.status == 403) {
      return const VistaEstado(
        key: Key('sin-acceso'),
        icono: Icons.lock_outline_rounded,
        titulo: 'Ya no puedes ver los datos de este servicio',
        mensaje:
            'La dirección y el contacto del cliente solo se muestran mientras '
            'el servicio está a tu cargo.',
      );
    }
    if (e is AppException && e.status == 404) {
      return const VistaEstado(
        key: Key('no-encontrada'),
        icono: Icons.search_off_rounded,
        titulo: 'No encontramos este servicio',
        mensaje: 'Puede que ya no esté asignado a ti.',
      );
    }
    return VistaError(
      key: const Key('error-solicitud'),
      error: e,
      titulo: 'No pudimos cargar el servicio',
      alReintentar: () => ref.invalidate(solicitudProvider(id)),
    );
  }
}

class _Encabezado extends ConsumerWidget {
  const _Encabezado(this.solicitud);

  final Solicitud solicitud;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sin catálogo, el servicio se muestra igual con un nombre genérico.
    final categorias = ref.watch(categoriasProvider).value ?? const [];
    final nombre = [
      for (final c in categorias)
        if (c.id == solicitud.categoriaId) c.nombre,
    ].firstOrNull;
    final texto = Theme.of(context).textTheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            iconoCategoria(nombre ?? ''),
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: QpEspacio.e3),
        // El estado va debajo del nombre para no desbordar con texto grande.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre ?? 'Servicio',
                key: const Key('categoria'),
                style: texto.titleLarge,
              ),
              const SizedBox(height: QpEspacio.e1),
              ChipEstado(solicitud.estado),
            ],
          ),
        ),
      ],
    );
  }
}

class _Cliente extends StatelessWidget {
  const _Cliente(this.cliente);

  final ClienteSolicitud? cliente;

  @override
  Widget build(BuildContext context) {
    // Si Identity no respondió, el contrato entrega nombre y teléfono en null.
    final nombre = cliente?.nombre;
    final telefono = cliente?.telefono;
    return _Seccion(
      titulo: 'Cliente',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nombre ?? 'Nombre no disponible por ahora',
            key: const Key('cliente-nombre'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: QpEspacio.e1),
          SelectableText(
            telefono ?? 'Teléfono no disponible por ahora',
            key: const Key('cliente-telefono'),
          ),
        ],
      ),
    );
  }
}

class _Ubicacion extends ConsumerStatefulWidget {
  const _Ubicacion(this.solicitud);

  final Solicitud solicitud;

  @override
  ConsumerState<_Ubicacion> createState() => _UbicacionState();
}

class _UbicacionState extends ConsumerState<_Ubicacion> {
  bool _copiada = false;

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: widget.solicitud.direccion));
    if (mounted) setState(() => _copiada = true);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;
    final mapa = ref.watch(mapaLocalidadesProvider).value;
    final localidades = ref.watch(localidadesProvider).value ?? const [];
    final punto = MapaLocalidades.proyectar(
      s.ubicacion.longitud,
      s.ubicacion.latitud,
    );
    final codigo = mapa?.localidadEn(punto);
    final localidad = [
      for (final l in localidades)
        if (l.codigo == codigo) l.nombre,
    ].firstOrNull;
    final secundario = Theme.of(context).colorScheme.onSurfaceVariant;
    return _Seccion(
      titulo: 'Dirección',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(s.direccion, key: const Key('direccion')),
          if (localidad != null) ...[
            const SizedBox(height: QpEspacio.e1),
            Text(
              'Localidad: $localidad',
              key: const Key('localidad'),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: secundario),
            ),
          ],
          const SizedBox(height: QpEspacio.e3),
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              liveRegion: true,
              child: OutlinedButton.icon(
                key: const Key('boton-copiar-direccion'),
                onPressed: _copiar,
                icon: Icon(_copiada ? Icons.check_rounded : Icons.copy_rounded),
                label: Text(
                  _copiada ? 'Dirección copiada' : 'Copiar dirección',
                ),
              ),
            ),
          ),
          // Sin el asset del mapa, la dirección y la localidad bastan.
          if (mapa != null) ...[
            const SizedBox(height: QpEspacio.e3),
            MapaBogota(
              key: const Key('mapa-servicio'),
              mapa: mapa,
              disponibles: mapa.codigos.toSet(),
              elegidas: {?codigo},
              punto: punto,
              encuadreInicial: codigo == null
                  ? null
                  : mapa.cajaDe(codigo)?.inflate(0.01),
              alto: 260,
            ),
          ],
        ],
      ),
    );
  }
}

class _IniciarServicio extends StatelessWidget {
  const _IniciarServicio(this.estado);

  final EstadoSolicitud estado;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const FilledButton(
        key: Key('boton-iniciar-servicio'),
        onPressed: null,
        child: Text('Iniciar servicio'),
      ),
      const SizedBox(height: QpEspacio.e2),
      Text(
        estado == EstadoSolicitud.cotizacionAceptada
            ? 'El cliente aceptó tu cotización. Iniciar el servicio desde la '
                  'app llega en una próxima versión.'
            : 'Podrás iniciarlo cuando el cliente acepte tu cotización.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(QpEspacio.e4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              titulo,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: QpEspacio.e2),
          child,
        ],
      ),
    ),
  );
}
