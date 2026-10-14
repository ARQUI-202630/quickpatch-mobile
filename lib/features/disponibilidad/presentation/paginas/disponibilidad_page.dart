import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/codigo_error.dart';
import '../../../../shared/widgets/boton_principal.dart';
import '../../../../shared/widgets/mensaje_error.dart';
import '../../../../shared/widgets/vista_error.dart';
import '../../../../shared/widgets/vista_estado.dart';
import '../../data/repositorio_disponibilidad.dart';
import '../../domain/modelos.dart';

/// Disponibilidad y zona de cobertura del técnico (RF-13, SCRUM-33 /
/// SCRUM-89). Contrato: `matching.v1.yaml`. Solo recibe ofertas cuando está
/// disponible y en las localidades que cubre (RN-M9).
class DisponibilidadPage extends StatelessWidget {
  const DisponibilidadPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Disponibilidad y cobertura')),
    body: const SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          QpEspacio.pantalla,
          QpEspacio.e2,
          QpEspacio.pantalla,
          QpEspacio.e8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Seccion('Tu disponibilidad'),
            _SeccionDisponibilidad(),
            SizedBox(height: QpEspacio.e6),
            _Seccion('Tus localidades'),
            _SeccionCobertura(),
          ],
        ),
      ),
    ),
  );
}

/// Mensaje del error de carga. Un 404 significa que Matching aún no procesa
/// el registro del técnico (`technician.registered`) y basta con reintentar.
Widget _vistaError(Object error, String titulo, VoidCallback reintentar) {
  final enPreparacion =
      error is AppException && error.codigo == CodigoError.notFound;
  return enPreparacion
      ? VistaEstado(
          key: const Key('cuenta-en-preparacion'),
          icono: Icons.hourglass_top_rounded,
          titulo: 'Estamos preparando tu cuenta.',
          mensaje: 'Intenta de nuevo en unos segundos.',
          accion: 'Reintentar',
          alAccionar: reintentar,
        )
      : VistaError(
          key: const Key('error-carga'),
          error: error,
          titulo: titulo,
          alReintentar: reintentar,
        );
}

class _SeccionDisponibilidad extends ConsumerStatefulWidget {
  const _SeccionDisponibilidad();

  @override
  ConsumerState<_SeccionDisponibilidad> createState() =>
      _SeccionDisponibilidadState();
}

class _SeccionDisponibilidadState
    extends ConsumerState<_SeccionDisponibilidad> {
  /// Estado guardado más reciente; null mientras no se ha cambiado aquí.
  Disponibilidad? _actual;
  bool _cambiando = false;
  String? _error;

  Future<void> _cambiar(bool disponible) async {
    setState(() {
      _cambiando = true;
      _error = null;
    });
    try {
      final nueva = await ref
          .read(repositorioDisponibilidadProvider)
          .cambiarDisponibilidad(disponible: disponible);
      if (mounted) setState(() => _actual = nueva);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.status == 409 || e.esProblema('transicion-invalida')
            ? _mensajeOcupado
            : e.mensaje;
      });
    } finally {
      if (mounted) setState(() => _cambiando = false);
    }
  }

  static const _mensajeOcupado =
      'Estás atendiendo un servicio. Tu disponibilidad cambia sola cuando '
      'lo termines.';

  @override
  Widget build(BuildContext context) {
    final cargada = ref.watch(disponibilidadProvider);
    return cargada.when(
      loading: () => const IndicadorCarga(etiqueta: 'Cargando disponibilidad'),
      error: (e, _) => _vistaError(
        e,
        'No pudimos cargar tu disponibilidad.',
        () => ref.invalidate(disponibilidadProvider),
      ),
      data: (inicial) {
        final disponibilidad = _actual ?? inicial;
        final ocupado = !disponibilidad.puedeCambiar;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: SwitchListTile(
                key: const Key('interruptor-disponibilidad'),
                title: const Text('Disponible para recibir ofertas'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: QpEspacio.e2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _ChipDisponibilidad(disponibilidad.estado),
                  ),
                ),
                value: disponibilidad.estado == EstadoDisponibilidad.disponible,
                onChanged: ocupado || _cambiando ? null : _cambiar,
              ),
            ),
            if (ocupado) ...[
              const SizedBox(height: QpEspacio.e3),
              const _Nota(_mensajeOcupado, key: Key('aviso-ocupado')),
            ],
            if (_error != null) ...[
              const SizedBox(height: QpEspacio.e3),
              MensajeError(_error!, key: const Key('error-disponibilidad')),
            ],
          ],
        );
      },
    );
  }
}

class _SeccionCobertura extends ConsumerStatefulWidget {
  const _SeccionCobertura();

  @override
  ConsumerState<_SeccionCobertura> createState() => _SeccionCoberturaState();
}

class _SeccionCoberturaState extends ConsumerState<_SeccionCobertura> {
  /// Códigos guardados en Matching y los que el técnico tiene marcados.
  Set<String>? _guardadas;
  Set<String>? _elegidas;
  bool _guardando = false;
  String? _error;

  Future<void> _guardar() async {
    final elegidas = _elegidas!;
    if (elegidas.isEmpty) {
      setState(() => _error = 'Elige al menos una localidad.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final cobertura = await ref
          .read(repositorioDisponibilidadProvider)
          .reemplazarCobertura(elegidas.toList()..sort());
      if (!mounted) return;
      setState(() {
        _guardadas = cobertura.codigos;
        _elegidas = {...cobertura.codigos};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guardamos tus localidades.')),
      );
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.errorDe('localityCodes') ?? e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localidades = ref.watch(localidadesProvider);
    final cobertura = ref.watch(coberturaProvider);
    void reintentar() {
      ref
        ..invalidate(localidadesProvider)
        ..invalidate(coberturaProvider);
    }

    if (localidades.hasError || cobertura.hasError) {
      return _vistaError(
        localidades.error ?? cobertura.error!,
        'No pudimos cargar las localidades.',
        reintentar,
      );
    }
    if (!localidades.hasValue || !cobertura.hasValue) {
      return const IndicadorCarga(etiqueta: 'Cargando localidades');
    }
    final lista = localidades.requireValue;
    if (lista.isEmpty) {
      return const VistaEstado(
        key: Key('sin-localidades'),
        icono: Icons.map_outlined,
        titulo: 'Todavía no hay localidades disponibles.',
      );
    }
    _guardadas ??= cobertura.requireValue.codigos;
    _elegidas ??= {..._guardadas!};
    final elegidas = _elegidas!;
    final cambio =
        elegidas.length != _guardadas!.length ||
        !elegidas.containsAll(_guardadas!);
    final texto = Theme.of(context).textTheme;
    final secundario = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Recibirás ofertas solo en las localidades que elijas.',
          style: texto.bodyMedium?.copyWith(color: secundario),
        ),
        const SizedBox(height: QpEspacio.e1),
        Text(
          '${elegidas.length} de ${lista.length} seleccionadas',
          key: const Key('conteo-localidades'),
          style: texto.bodySmall?.copyWith(color: secundario),
        ),
        const SizedBox(height: QpEspacio.e3),
        Wrap(
          spacing: QpEspacio.e2,
          runSpacing: QpEspacio.e2,
          children: [
            for (final localidad in lista)
              FilterChip(
                key: Key('localidad-${localidad.codigo}'),
                label: Text(localidad.nombre),
                selected: elegidas.contains(localidad.codigo),
                onSelected: _guardando
                    ? null
                    : (marcada) => setState(() {
                        _error = null;
                        marcada
                            ? elegidas.add(localidad.codigo)
                            : elegidas.remove(localidad.codigo);
                      }),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: QpEspacio.e4),
          MensajeError(_error!, key: const Key('error-cobertura')),
        ],
        const SizedBox(height: QpEspacio.e6),
        BotonPrincipal(
          key: const Key('boton-guardar-cobertura'),
          texto: 'Guardar localidades',
          cargando: _guardando,
          alPresionar: cambio ? _guardar : () {},
        ),
        if (!cambio)
          Padding(
            padding: const EdgeInsets.only(top: QpEspacio.e2),
            child: Text(
              'No hay cambios por guardar.',
              textAlign: TextAlign.center,
              style: texto.bodySmall?.copyWith(color: secundario),
            ),
          ),
      ],
    );
  }
}

/// Insignia del estado con su tono (disponible en éxito, ocupado en aviso).
class _ChipDisponibilidad extends StatelessWidget {
  const _ChipDisponibilidad(this.estado);

  final EstadoDisponibilidad estado;

  @override
  Widget build(BuildContext context) {
    final estados = context.estados;
    final (color, fondo, icono) = switch (estado) {
      EstadoDisponibilidad.disponible => (
        estados.exito,
        estados.exitoFondo,
        Icons.check_circle_outline_rounded,
      ),
      EstadoDisponibilidad.ocupado => (
        estados.aviso,
        estados.avisoFondo,
        Icons.handyman_outlined,
      ),
      EstadoDisponibilidad.noDisponible => (
        Theme.of(context).colorScheme.onSurfaceVariant,
        Theme.of(context).colorScheme.surfaceContainerHighest,
        Icons.pause_circle_outline_rounded,
      ),
    };
    return Semantics(
      label: 'Estado: ${estado.etiqueta}',
      excludeSemantics: true,
      child: DecoratedBox(
        key: Key('estado-${estado.valor}'),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(QpRadio.pildora),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: QpEspacio.e3,
            vertical: QpEspacio.e1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 16, color: color),
              const SizedBox(width: QpEspacio.e1),
              Flexible(
                child: Text(
                  estado.etiqueta,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso informativo en el tono de aviso del tema.
class _Nota extends StatelessWidget {
  const _Nota(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final estados = context.estados;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: estados.avisoFondo,
        borderRadius: BorderRadius.circular(QpRadio.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(QpEspacio.e4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: estados.aviso),
            const SizedBox(width: QpEspacio.e3),
            Expanded(
              child: Text(
                texto,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: estados.aviso),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: QpEspacio.e3),
    child: Semantics(
      header: true,
      child: Text(titulo, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}
