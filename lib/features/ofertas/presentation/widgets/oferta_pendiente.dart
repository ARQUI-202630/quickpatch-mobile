import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/catalogo/repositorio_catalogo.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/realtime/canal_tiempo_real.dart';
import '../../../../core/realtime/mensaje_tiempo_real.dart';
import '../../../../core/utils/reloj.dart';
import '../../../../shared/widgets/icono_categoria.dart';
import '../../data/repositorio_ofertas.dart';
import '../../domain/oferta.dart';

/// Oferta pendiente del técnico, arriba de su pestaña Servicios (RF-10,
/// SCRUM-30 / SCRUM-80). Muestra el servicio, la localidad y la distancia,
/// sin la dirección (RN-SR13), con el tiempo que le queda (RN-M8).
///
/// Se consulta al abrir, con el aviso `offer.created` del canal en tiempo
/// real y, si el canal no está conectado, cada 30 s (ADR-023). Sin oferta no
/// ocupa espacio.
class OfertaPendiente extends ConsumerStatefulWidget {
  const OfertaPendiente({super.key});

  @override
  ConsumerState<OfertaPendiente> createState() => _OfertaPendienteState();
}

class _OfertaPendienteState extends ConsumerState<OfertaPendiente> {
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

  @override
  void dispose() {
    _respaldo?.cancel();
    unawaited(_avisos?.cancel());
    super.dispose();
  }

  void _actualizar() {
    if (mounted) ref.invalidate(ofertaPendienteProvider);
  }

  /// Se suscribe al canal actual; cambia si la sesión crea uno nuevo.
  void _escuchar(CanalTiempoReal canal) {
    if (identical(canal, _canal)) return;
    unawaited(_avisos?.cancel());
    _canal = canal;
    _avisos = canal.avisos
        .where((m) => m.tipo == MensajeTiempoReal.ofertaCreada)
        .listen((_) => _actualizar());
  }

  @override
  Widget build(BuildContext context) {
    _escuchar(ref.watch(canalTiempoRealProvider));
    final oferta = ref.watch(ofertaPendienteProvider);
    return switch (oferta) {
      AsyncData(value: final o?) => Padding(
        padding: const EdgeInsets.only(bottom: QpEspacio.e3),
        child: TarjetaOferta(
          key: ValueKey(o.attemptId),
          oferta: o,
          alTerminar: _actualizar,
        ),
      ),
      // Sin oferta, o mientras carga la primera vez, no ocupa espacio.
      AsyncError(:final error) when !oferta.hasValue => _ErrorOferta(
        error: error,
        alReintentar: _actualizar,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _ErrorOferta extends StatelessWidget {
  const _ErrorOferta({required this.error, required this.alReintentar});

  final Object error;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    final mensaje = error is AppException
        ? (error as AppException).mensaje
        : 'Ocurrió un error inesperado.';
    return Padding(
      padding: const EdgeInsets.only(bottom: QpEspacio.e3),
      child: Card(
        key: const Key('error-oferta'),
        child: Padding(
          padding: const EdgeInsets.all(QpEspacio.e3),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: QpEspacio.e2,
            runSpacing: QpEspacio.e2,
            children: [
              Text('No pudimos consultar tus ofertas. $mensaje'),
              TextButton(
                onPressed: alReintentar,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de la oferta con su cuenta regresiva y las acciones.
class TarjetaOferta extends ConsumerStatefulWidget {
  const TarjetaOferta({
    super.key,
    required this.oferta,
    required this.alTerminar,
  });

  final Oferta oferta;

  /// Se llama cuando la oferta deja de estar pendiente (respondida, vencida
  /// o no disponible), para volver a consultar.
  final VoidCallback alTerminar;

  @override
  ConsumerState<TarjetaOferta> createState() => _TarjetaOfertaState();
}

enum _Accion { aceptar, rechazar }

class _TarjetaOfertaState extends ConsumerState<TarjetaOferta> {
  Timer? _cuenta;
  _Accion? _enCurso;
  bool _avisoVencida = false;

  /// Tras vencer, consulta cada [esperaTrasVencer] hasta que la oferta
  /// desaparezca. La cuenta usa el reloj del teléfono, pero Matching decide
  /// el vencimiento con el del servidor: si el teléfono va adelantado, la
  /// oferta sigue pendiente un momento más.
  static const esperaTrasVencer = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _cuenta = Timer.periodic(const Duration(seconds: 1), (_) => _tic());
  }

  @override
  void dispose() {
    _cuenta?.cancel();
    super.dispose();
  }

  Duration get _restante => widget.oferta.restante(ref.read(relojProvider)());

  void _tic() {
    if (!mounted) return;
    setState(() {});
    if (_restante == Duration.zero && !_avisoVencida) {
      _avisoVencida = true;
      _cuenta?.cancel();
      _cuenta = Timer.periodic(esperaTrasVencer, (_) => widget.alTerminar());
    }
  }

  Future<void> _aceptar() async {
    setState(() => _enCurso = _Accion.aceptar);
    final oferta = widget.oferta;
    // La tarjeta desaparece al aceptar: la acción del aviso usa el router.
    final router = GoRouter.of(context);
    try {
      await ref.read(repositorioOfertasProvider).aceptar(oferta.attemptId);
      if (!mounted) return;
      _avisar(
        'Aceptaste el servicio.',
        accion: SnackBarAction(
          label: 'Ver',
          // El detalle puede tardar un momento en estar listo: ServiceRequest
          // aplica la asignación cuando recibe el evento de Matching.
          onPressed: () =>
              router.push(Rutas.solicitudAsignada(oferta.serviceRequestId)),
        ),
      );
      widget.alTerminar();
    } on AppException catch (e) {
      _fallo(e);
    }
  }

  Future<void> _rechazar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Rechazar esta oferta?'),
        content: const Text(
          'No tiene penalización. Le ofreceremos el servicio a otro técnico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            key: const Key('confirmar-rechazo'),
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() => _enCurso = _Accion.rechazar);
    try {
      await ref
          .read(repositorioOfertasProvider)
          .rechazar(widget.oferta.attemptId);
      if (!mounted) return;
      _avisar('Rechazaste la oferta.');
      widget.alTerminar();
    } on AppException catch (e) {
      _fallo(e);
    }
  }

  void _fallo(AppException e) {
    if (!mounted) return;
    setState(() => _enCurso = null);
    final router = GoRouter.of(context);
    if (e.esProblema('oferta-no-disponible')) {
      _avisar('Esta oferta ya no está disponible.');
      widget.alTerminar();
    } else if (e.esProblema('tecnico-no-disponible')) {
      _avisar(
        'Ya no estás disponible para aceptar ofertas.',
        accion: SnackBarAction(
          label: 'Disponibilidad',
          onPressed: () => router.push(Rutas.disponibilidad),
        ),
      );
      widget.alTerminar();
    } else {
      _avisar(e.mensaje);
    }
  }

  void _avisar(String mensaje, {SnackBarAction? accion}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje), action: accion));
  }

  @override
  Widget build(BuildContext context) {
    final oferta = widget.oferta;
    final esquema = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    final secundario = texto.bodyMedium?.copyWith(
      color: esquema.onSurfaceVariant,
    );
    // Sin la réplica del catálogo en Matching, el nombre sale del catálogo.
    final categorias = ref.watch(categoriasProvider).value ?? const [];
    final servicio =
        oferta.categoriaNombre ??
        [
          for (final c in categorias)
            if (c.id == oferta.categoriaId) c.nombre,
        ].firstOrNull ??
        'Servicio';
    final restante = _restante;
    final vencida = restante == Duration.zero;
    final ocupado = _enCurso != null;

    return Card(
      key: const Key('tarjeta-oferta'),
      color: esquema.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(QpEspacio.e4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Nueva oferta',
                style: texto.labelLarge?.copyWith(
                  color: esquema.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: QpEspacio.e2),
            Row(
              children: [
                Icon(iconoCategoria(servicio), color: esquema.primary),
                const SizedBox(width: QpEspacio.e2),
                Expanded(
                  child: Text(
                    servicio,
                    key: const Key('oferta-servicio'),
                    style: texto.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: QpEspacio.e2),
            // Las solicitudes viejas de Matching pueden no tener descripción.
            if (oferta.descripcion.trim().isEmpty)
              Text(
                'Sin descripción',
                key: const Key('oferta-descripcion'),
                style: secundario?.copyWith(fontStyle: FontStyle.italic),
              )
            else
              Text(
                oferta.descripcion,
                key: const Key('oferta-descripcion'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: QpEspacio.e2),
            Text(
              '${oferta.localidad.nombre} · '
              '${distanciaLegible(oferta.distanciaMetros)}',
              key: const Key('oferta-lugar'),
              style: secundario,
            ),
            const SizedBox(height: QpEspacio.e1),
            Semantics(
              liveRegion: vencida,
              child: Text(
                vencida
                    ? 'La oferta venció.'
                    : 'Vence en ${cuentaRegresiva(restante)}',
                key: const Key('oferta-tiempo'),
                style: texto.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: vencida ? esquema.error : esquema.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: QpEspacio.e3),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: QpEspacio.e2,
              runSpacing: QpEspacio.e2,
              children: [
                OutlinedButton(
                  key: const Key('boton-rechazar-oferta'),
                  onPressed: vencida || ocupado ? null : _rechazar,
                  child: Text(
                    _enCurso == _Accion.rechazar ? 'Rechazando…' : 'Rechazar',
                  ),
                ),
                FilledButton(
                  key: const Key('boton-aceptar-oferta'),
                  onPressed: vencida || ocupado ? null : _aceptar,
                  child: Text(
                    _enCurso == _Accion.aceptar ? 'Aceptando…' : 'Aceptar',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// «a 850 m» o «a 1,2 km».
String distanciaLegible(double metros) {
  if (metros < 1000) return 'a ${metros.round()} m';
  final km = (metros / 1000).toStringAsFixed(1).replaceAll('.', ',');
  return 'a $km km';
}

/// «2:05» para el tiempo que le queda a la oferta.
String cuentaRegresiva(Duration restante) {
  final segundos = restante.inSeconds;
  final s = (segundos % 60).toString().padLeft(2, '0');
  return '${segundos ~/ 60}:$s';
}
