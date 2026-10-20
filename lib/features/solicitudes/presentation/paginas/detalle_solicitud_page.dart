import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/catalogo/repositorio_catalogo.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/realtime/canal_tiempo_real.dart';
import '../../../../core/realtime/mensaje_tiempo_real.dart';
import '../../../../core/utils/fechas.dart';
import '../../../../shared/widgets/vista_error.dart';
import '../../data/repositorio_solicitudes.dart';
import '../../domain/modelos.dart';
import '../estado_vista.dart';
import '../widgets/cotizacion_cliente.dart';
import '../widgets/evidencia_cliente.dart';

/// Detalle y seguimiento de una solicitud (SCRUM-27, SCRUM-83) y su
/// cancelación (SCRUM-477). Contrato: `GET /v1/service-requests/{id}` y
/// `POST /v1/service-requests/{id}/cancel` (1.5.0). En `cotizado` el cliente
/// acepta o rechaza la cotización (SCRUM-489, 1.6.0).
///
/// El canal `/v1/realtime` (ADR-023) solo avisa que el estado cambió; la
/// pantalla vuelve a pedir el detalle, que es la fuente de verdad. Si el canal
/// no está conectado, consulta el detalle cada 30 s (RNF-06).
class DetalleSolicitudPage extends ConsumerStatefulWidget {
  const DetalleSolicitudPage({required this.id, super.key});

  final String id;

  @override
  ConsumerState<DetalleSolicitudPage> createState() =>
      _DetalleSolicitudPageState();
}

class _DetalleSolicitudPageState extends ConsumerState<DetalleSolicitudPage> {
  CanalTiempoReal? _canal;
  StreamSubscription<MensajeTiempoReal>? _avisos;
  Timer? _respaldo;

  @override
  void initState() {
    super.initState();
    _respaldo = Timer.periodic(MensajeTiempoReal.intervaloRespaldo, (_) {
      if (_canal?.estado.value != EstadoCanal.conectado) _actualizar();
    });
  }

  void _actualizar() {
    ref
      ..invalidate(solicitudProvider(widget.id))
      ..invalidate(cotizacionesProvider(widget.id))
      ..invalidate(evidenciasProvider(widget.id));
  }

  /// Se suscribe al canal actual; cambia si la sesión crea uno nuevo.
  void _escuchar(CanalTiempoReal canal) {
    if (identical(canal, _canal)) return;
    unawaited(_avisos?.cancel());
    _canal = canal;
    _avisos = canal.avisos
        .where((m) => m.cambiaSolicitud(widget.id))
        .listen((_) => _actualizar());
  }

  @override
  void dispose() {
    _respaldo?.cancel();
    unawaited(_avisos?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canal = ref.watch(canalTiempoRealProvider);
    _escuchar(canal);
    final solicitud = ref.watch(solicitudProvider(widget.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu solicitud'),
        leading: IconButton(
          tooltip: 'Inicio',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => context.go(Rutas.inicio),
        ),
      ),
      body: solicitud.when(
        // Al volver a consultar se conserva lo que ya se veía.
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const IndicadorCarga(),
        error: (e, _) => Center(
          child: SingleChildScrollView(
            child: VistaError(
              key: const Key('detalle-error'),
              error: e,
              titulo: 'No pudimos cargar la solicitud',
              alReintentar: _actualizar,
            ),
          ),
        ),
        data: (s) => RefreshIndicator(
          onRefresh: () {
            ref
              ..invalidate(cotizacionesProvider(widget.id))
              ..invalidate(evidenciasProvider(widget.id));
            return ref.refresh(solicitudProvider(widget.id).future);
          },
          child: ListView(
            padding: const EdgeInsets.all(QpEspacio.pantalla),
            children: [
              Align(child: _IndicadorTiempoReal(canal.estado)),
              const SizedBox(height: QpEspacio.e3),
              _EncabezadoEstado(s.estado),
              const SizedBox(height: QpEspacio.e4),
              if (CotizacionCliente.aplica(s.estado)) ...[
                CotizacionCliente(solicitud: s, alCambiar: _actualizar),
                const SizedBox(height: QpEspacio.e4),
              ],
              if (EvidenciaCliente.aplica(s.estado)) ...[
                EvidenciaCliente(solicitud: s),
                const SizedBox(height: QpEspacio.e4),
              ],
              if (s.estado != EstadoSolicitud.cancelado) ...[
                _LineaDeTiempo(s.estado),
                const SizedBox(height: QpEspacio.e4),
              ] else ...[
                _TarjetaCancelacion(s),
                const SizedBox(height: QpEspacio.e4),
              ],
              _TarjetaTecnico(s),
              const SizedBox(height: QpEspacio.e4),
              _Datos(s),
              const SizedBox(height: QpEspacio.e4),
              if (s.estado.cancelable) ...[
                _BotonCancelar(solicitudId: s.id, alTerminar: _actualizar),
                const SizedBox(height: QpEspacio.e4),
              ],
              Text(
                'Desliza hacia abajo para actualizar el estado.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "En vivo" con el canal conectado; si no, avisa que se consulta cada 30 s.
class _IndicadorTiempoReal extends StatelessWidget {
  const _IndicadorTiempoReal(this.estado);

  final ValueListenable<EstadoCanal> estado;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: estado,
    builder: (context, valor, _) {
      final enVivo = valor == EstadoCanal.conectado;
      final colores = context.estados;
      final color = enVivo ? colores.exito : colores.aviso;
      return DecoratedBox(
        key: const Key('indicador-tiempo-real'),
        decoration: BoxDecoration(
          color: enVivo ? colores.exitoFondo : colores.avisoFondo,
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
              Icon(
                enVivo ? Icons.circle : Icons.sync_rounded,
                size: 12,
                color: color,
              ),
              const SizedBox(width: QpEspacio.e2),
              Flexible(
                child: Text(
                  enVivo ? 'En vivo' : 'Actualizando cada 30 s',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _EncabezadoEstado extends StatelessWidget {
  const _EncabezadoEstado(this.estado);

  final EstadoSolicitud estado;

  @override
  Widget build(BuildContext context) {
    final vista = vistaDe(estado);
    final (color, fondo) = vista.colores(context.estados);
    final texto = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(QpEspacio.e5),
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(QpEspacio.e4),
                child: Icon(vista.icono, size: 36, color: color),
              ),
            ),
            const SizedBox(height: QpEspacio.e4),
            Text(
              estado.etiqueta,
              key: const Key('estado-solicitud'),
              textAlign: TextAlign.center,
              style: texto.headlineSmall,
            ),
            const SizedBox(height: QpEspacio.e2),
            Text(
              vista.descripcion,
              textAlign: TextAlign.center,
              style: texto.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pasos que ve el cliente. Los estados intermedios del contrato (en espera,
/// cotizaciones, pago) se agrupan en el paso más cercano.
const pasosSeguimiento = [
  'Buscando técnico',
  'Asignado',
  'En progreso',
  'Completado',
];

/// Índice del paso actual en [pasosSeguimiento]; `null` si está cancelada.
int? pasoDe(EstadoSolicitud estado) => switch (estado) {
  EstadoSolicitud.buscandoTecnico || EstadoSolicitud.enEspera => 0,
  EstadoSolicitud.asignado ||
  EstadoSolicitud.cotizado ||
  EstadoSolicitud.cotizacionAceptada => 1,
  EstadoSolicitud.enProgreso => 2,
  EstadoSolicitud.completado || EstadoSolicitud.pagado => 3,
  EstadoSolicitud.cancelado => null,
};

class _LineaDeTiempo extends StatelessWidget {
  const _LineaDeTiempo(this.estado);

  final EstadoSolicitud estado;

  @override
  Widget build(BuildContext context) {
    final actual = pasoDe(estado)!;
    return Card(
      key: const Key('linea-de-tiempo'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: QpEspacio.e3),
        child: Column(
          children: [
            for (var i = 0; i < pasosSeguimiento.length; i++)
              _Paso(
                indice: i,
                // El último paso queda hecho cuando el servicio terminó.
                hecho: i < actual || (i == actual && i == 3),
                actual: i == actual && i != 3,
                ultimo: i == pasosSeguimiento.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({
    required this.indice,
    required this.hecho,
    required this.actual,
    required this.ultimo,
  });

  final int indice;
  final bool hecho;
  final bool actual;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final exito = context.estados.exito;
    final color = hecho
        ? exito
        : actual
        ? esquema.primary
        : esquema.outline;
    final titulo = pasosSeguimiento[indice];
    final situacion = hecho
        ? 'completado'
        : actual
        ? 'en curso'
        : 'pendiente';
    return MergeSemantics(
      child: Semantics(
        label:
            'Paso ${indice + 1} de ${pasosSeguimiento.length}: $titulo, '
            '$situacion',
        excludeSemantics: true,
        child: ListTile(
          key: Key('paso-$indice'),
          leading: Icon(
            hecho
                ? Icons.check_circle_rounded
                : actual
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: color,
          ),
          title: Text(
            titulo,
            style: actual
                ? Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)
                : null,
          ),
          subtitle: actual ? const Text('Ahora') : null,
          dense: !actual,
        ),
      ),
    );
  }
}

/// Técnico asignado con su especialidad (la categoría de la solicitud).
class _TarjetaTecnico extends ConsumerWidget {
  const _TarjetaTecnico(this.solicitud);

  final Solicitud solicitud;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tecnico = solicitud.tecnico;
    if (tecnico == null) {
      final paso = pasoDe(solicitud.estado);
      if (paso == null) return const SizedBox.shrink();
      if (paso > 0) {
        // Ya hay técnico, pero el detalle aún no trae sus datos (por ejemplo,
        // un backend anterior a la 1.1.0).
        return const Card(
          key: Key('tecnico-sin-datos'),
          child: ListTile(
            leading: Icon(Icons.engineering_outlined),
            title: Text('Ya tienes un técnico asignado'),
            subtitle: Text('Pronto verás sus datos aquí.'),
          ),
        );
      }
      return const Card(
        key: Key('sin-tecnico'),
        child: ListTile(
          leading: Icon(Icons.person_search_outlined),
          title: Text('Aún no hay técnico asignado'),
          subtitle: Text('Te avisaremos aquí cuando alguien acepte.'),
        ),
      );
    }
    final especialidad = ref
        .watch(categoriasProvider)
        .whenOrNull(
          data: (categorias) => categorias
              .where((c) => c.id == solicitud.categoriaId)
              .map((c) => c.nombre)
              .firstOrNull,
        );
    final nombre = tecnico.nombre ?? 'Técnico asignado';
    final asignada = solicitud.asignadaEn;
    return Card(
      key: const Key('tarjeta-tecnico'),
      child: ListTile(
        leading: CircleAvatar(child: Text(_iniciales(nombre))),
        title: Text(nombre),
        subtitle: Text(
          [
            especialidad ?? 'Técnico asignado',
            if (asignada != null) 'Desde ${fechaCorta(asignada.toLocal())}',
          ].join('\n'),
        ),
        isThreeLine: asignada != null,
      ),
    );
  }

  static String _iniciales(String nombre) => nombre
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();
}

class _Datos extends StatelessWidget {
  const _Datos(this.solicitud);

  final Solicitud solicitud;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        _Fila(Icons.description_outlined, 'Descripción', solicitud.descripcion),
        _Fila(Icons.place_outlined, 'Dirección', solicitud.direccion),
        _Fila(
          Icons.schedule_rounded,
          'Creada',
          fechaCorta(solicitud.creadaEn.toLocal()),
        ),
        _Fila(Icons.tag_rounded, 'Número de solicitud', solicitud.id),
      ],
    ),
  );
}

/// Cuándo y por qué se canceló la solicitud (1.5.0).
class _TarjetaCancelacion extends StatelessWidget {
  const _TarjetaCancelacion(this.solicitud);

  final Solicitud solicitud;

  @override
  Widget build(BuildContext context) {
    final cancelada = solicitud.canceladaEn;
    final motivo = solicitud.motivoCancelacion;
    if (cancelada == null && motivo == null) return const SizedBox.shrink();
    return Card(
      key: const Key('tarjeta-cancelacion'),
      child: Column(
        children: [
          if (cancelada != null)
            _Fila(
              Icons.event_busy_outlined,
              'Cancelada',
              fechaCorta(cancelada.toLocal()),
            ),
          if (motivo != null) _Fila(Icons.notes_rounded, 'Motivo', motivo),
        ],
      ),
    );
  }
}

/// Cancela la solicitud mientras el servicio no haya iniciado (RF-36,
/// SCRUM-477). Solo se muestra en los estados cancelables; el backend vuelve a
/// validarlo y responde `409` si el servicio ya inició.
class _BotonCancelar extends StatelessWidget {
  const _BotonCancelar({required this.solicitudId, required this.alTerminar});

  final String solicitudId;
  final VoidCallback alTerminar;

  Future<void> _cancelar(BuildContext context) async {
    final mensajero = ScaffoldMessenger.of(context);
    final aviso = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoCancelar(solicitudId),
    );
    if (aviso == null) return;
    mensajero.showSnackBar(SnackBar(content: Text(aviso)));
    alTerminar();
  }

  @override
  Widget build(BuildContext context) {
    final peligro = context.estados.peligro;
    return OutlinedButton.icon(
      key: const Key('boton-cancelar-solicitud'),
      style: OutlinedButton.styleFrom(
        foregroundColor: peligro,
        side: BorderSide(color: peligro),
      ),
      onPressed: () => _cancelar(context),
      icon: const Icon(Icons.cancel_outlined),
      label: const Text('Cancelar solicitud'),
    );
  }
}

/// Pide el motivo y cancela. Se cierra con el aviso para el cliente, o con
/// `null` si vuelve sin cancelar.
class _DialogoCancelar extends ConsumerStatefulWidget {
  const _DialogoCancelar(this.solicitudId);

  final String solicitudId;

  @override
  ConsumerState<_DialogoCancelar> createState() => _DialogoCancelarState();
}

class _DialogoCancelarState extends ConsumerState<_DialogoCancelar> {
  final _motivo = TextEditingController();
  String? _error;
  var _enviando = false;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final motivo = _motivo.text.trim();
    if (motivo.length < MotivoCancelacion.minimo) {
      setState(
        () => _error =
            'Escribe el motivo (mínimo ${MotivoCancelacion.minimo} '
            'caracteres).',
      );
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ref
          .read(repositorioSolicitudesProvider)
          .cancelar(widget.solicitudId, motivo);
      if (mounted) Navigator.of(context).pop('Cancelaste la solicitud.');
    } on AppException catch (e) {
      if (!mounted) return;
      if (e.esProblema('transicion-invalida')) {
        Navigator.of(
          context,
        ).pop('El servicio ya inició: la solicitud ya no se puede cancelar.');
        return;
      }
      setState(() {
        _enviando = false;
        _error = e.errorDe('reason') ?? e.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final peligro = context.estados.peligro;
    return AlertDialog(
      title: const Text('¿Cancelar la solicitud?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Dejaremos de buscar técnico o le avisaremos al técnico '
              'asignado. No podrás reactivarla.',
            ),
            const SizedBox(height: QpEspacio.e4),
            TextField(
              key: const Key('campo-motivo-cancelacion'),
              controller: _motivo,
              enabled: !_enviando,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: MotivoCancelacion.maximo,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Motivo',
                hintText: 'Por ejemplo: ya no necesito el servicio',
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.of(context).pop(),
          child: const Text('Volver'),
        ),
        FilledButton(
          key: const Key('confirmar-cancelacion'),
          style: FilledButton.styleFrom(
            backgroundColor: peligro,
            foregroundColor: esquema.surface,
          ),
          onPressed: _enviando ? null : _confirmar,
          child: _enviando
              ? Semantics(
                  label: 'Cancelando',
                  child: const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Text('Cancelar solicitud'),
        ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.icono, this.titulo, this.valor);

  final IconData icono;
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icono),
    title: Text(titulo),
    subtitle: Text(valor),
  );
}
