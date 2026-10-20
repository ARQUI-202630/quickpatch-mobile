import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/fechas.dart';
import '../../data/repositorio_solicitudes.dart';
import '../../data/selector_fotos.dart';
import '../../domain/modelos.dart';
import 'cotizacion_tecnico.dart' show SeccionCotizacion;
import 'galeria_evidencias.dart';

/// Ejecución del servicio desde la app del técnico (RF-14, RF-15, SCRUM-95;
/// service-request 1.7.0).
///
/// - Antes de que el cliente acepte la cotización, el botón de iniciar está
///   deshabilitado (RN-SR6).
/// - En `cotizacion_aceptada`, inicia el servicio.
/// - En `en_progreso`, toma o elige fotos, las sube y completa; completar se
///   habilita con al menos una foto (RN-SR3), y como máximo 10 (RN-E4).
/// - En `completado`, muestra las fotos que subió.
///
/// El backend vuelve a validar cada paso: un `409` avisa y recarga.
class EjecucionTecnico extends StatelessWidget {
  const EjecucionTecnico({
    required this.solicitud,
    required this.alCambiar,
    super.key,
  });

  final Solicitud solicitud;

  /// Vuelve a pedir la solicitud, sus cotizaciones y sus fotos.
  final VoidCallback alCambiar;

  static bool aplica(EstadoSolicitud estado) => switch (estado) {
    EstadoSolicitud.asignado ||
    EstadoSolicitud.cotizado ||
    EstadoSolicitud.cotizacionAceptada ||
    EstadoSolicitud.enProgreso ||
    EstadoSolicitud.completado => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) => switch (solicitud.estado) {
    EstadoSolicitud.asignado || EstadoSolicitud.cotizado => const _Ayuda(
      boton: FilledButton(
        key: Key('boton-iniciar-servicio'),
        onPressed: null,
        child: Text('Iniciar servicio'),
      ),
      texto: 'Podrás iniciarlo cuando el cliente acepte tu cotización.',
    ),
    EstadoSolicitud.cotizacionAceptada => _Iniciar(
      solicitudId: solicitud.id,
      alCambiar: alCambiar,
    ),
    EstadoSolicitud.enProgreso => _EnProgreso(
      solicitudId: solicitud.id,
      alCambiar: alCambiar,
    ),
    EstadoSolicitud.completado => _Completado(solicitud),
    _ => const SizedBox.shrink(),
  };
}

/// Aviso de un `409`: la solicitud cambió (por ejemplo, la canceló el cliente
/// antes de iniciar) y el paso ya no aplica.
const avisoCambio =
    'La solicitud cambió y este paso ya no aplica. Actualizamos el servicio.';

class _Ayuda extends StatelessWidget {
  const _Ayuda({required this.boton, required this.texto});

  final Widget boton;
  final String texto;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      boton,
      const SizedBox(height: QpEspacio.e2),
      Text(
        texto,
        key: const Key('ayuda-ejecucion'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}

Future<bool> _confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String accion,
  required Key clave,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            key: clave,
            onPressed: () => Navigator.of(contexto).pop(true),
            child: Text(accion),
          ),
        ],
      ),
    ) ==
    true;

class _Iniciar extends ConsumerStatefulWidget {
  const _Iniciar({required this.solicitudId, required this.alCambiar});

  final String solicitudId;
  final VoidCallback alCambiar;

  @override
  ConsumerState<_Iniciar> createState() => _IniciarState();
}

class _IniciarState extends ConsumerState<_Iniciar> {
  var _enviando = false;

  Future<void> _iniciar() async {
    final mensajero = ScaffoldMessenger.of(context);
    final confirmado = await _confirmar(
      context,
      titulo: '¿Iniciar el servicio?',
      mensaje:
          'El cliente verá que empezaste. Antes de completarlo tendrás que '
          'subir al menos una foto del trabajo.',
      accion: 'Iniciar',
      clave: const Key('confirmar-iniciar'),
    );
    if (!confirmado || !mounted) return;
    setState(() => _enviando = true);
    try {
      await ref
          .read(repositorioSolicitudesProvider)
          .iniciar(widget.solicitudId);
      // El botón sigue ocupado hasta que la pantalla recargue en en_progreso.
      mensajero.showSnackBar(
        const SnackBar(
          content: Text('Iniciaste el servicio. Sube fotos del trabajo.'),
        ),
      );
      widget.alCambiar();
    } on AppException catch (e) {
      if (mounted) setState(() => _enviando = false);
      mensajero.showSnackBar(
        SnackBar(content: Text(e.status == 409 ? avisoCambio : e.mensaje)),
      );
      if (e.status == 409) widget.alCambiar();
    }
  }

  @override
  Widget build(BuildContext context) => _Ayuda(
    boton: FilledButton.icon(
      key: const Key('boton-iniciar-servicio'),
      onPressed: _enviando ? null : _iniciar,
      icon: _enviando
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.play_arrow_rounded),
      label: const Text('Iniciar servicio'),
    ),
    texto: 'El cliente aceptó tu cotización: ya puedes empezar.',
  );
}

class _EnProgreso extends ConsumerStatefulWidget {
  const _EnProgreso({required this.solicitudId, required this.alCambiar});

  final String solicitudId;
  final VoidCallback alCambiar;

  @override
  ConsumerState<_EnProgreso> createState() => _EnProgresoState();
}

class _EnProgresoState extends ConsumerState<_EnProgreso> {
  /// Avance de la subida en curso (0 a 1); `null` si no se sube nada.
  double? _avance;
  var _completando = false;
  String? _error;

  bool get _subiendo => _avance != null;

  void _recargarFotos() =>
      ref.invalidate(evidenciasProvider(widget.solicitudId));

  Future<void> _subir(OrigenFoto origen) async {
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _error = null);
    final foto = await ref.read(selectorFotosProvider).elegir(origen);
    if (foto == null || !mounted) return;
    if (foto.bytes.length > LimitesEvidencia.bytesMaximos) {
      setState(() => _error = 'La foto pesa más de 10 MB. Prueba con otra.');
      return;
    }
    setState(() => _avance = 0);
    try {
      await ref
          .read(repositorioSolicitudesProvider)
          .subirEvidencia(
            widget.solicitudId,
            foto.bytes,
            nombre: foto.nombre,
            alAvanzar: (avance) {
              if (mounted) setState(() => _avance = avance);
            },
          );
      mensajero.showSnackBar(const SnackBar(content: Text('Foto subida.')));
      _recargarFotos();
    } on AppException catch (e) {
      if (e.esProblema('limite-de-evidencias')) {
        _error = 'Ya subiste las ${LimitesEvidencia.maximo} fotos permitidas.';
        _recargarFotos();
      } else if (e.status == 409) {
        mensajero.showSnackBar(const SnackBar(content: Text(avisoCambio)));
        widget.alCambiar();
      } else {
        _error = e.errorDe('file') ?? e.mensaje;
      }
    } finally {
      if (mounted) setState(() => _avance = null);
    }
  }

  Future<void> _completar() async {
    final mensajero = ScaffoldMessenger.of(context);
    final confirmado = await _confirmar(
      context,
      titulo: '¿Marcar el servicio como completado?',
      mensaje:
          'El cliente verá el servicio terminado con tus fotos y podrá '
          'pagarlo. Después no podrás subir más fotos.',
      accion: 'Completar',
      clave: const Key('confirmar-completar'),
    );
    if (!confirmado || !mounted) return;
    setState(() {
      _completando = true;
      _error = null;
    });
    try {
      await ref
          .read(repositorioSolicitudesProvider)
          .completar(widget.solicitudId);
      // Sigue ocupado hasta que la pantalla recargue en completado.
      mensajero.showSnackBar(
        const SnackBar(
          content: Text(
            'Completaste el servicio. El cliente ya puede pagarlo.',
          ),
        ),
      );
      widget.alCambiar();
    } on AppException catch (e) {
      if (mounted) setState(() => _completando = false);
      if (e.status == 422) {
        setState(() => _error = 'Sube al menos una foto del trabajo.');
        _recargarFotos();
      } else {
        mensajero.showSnackBar(
          SnackBar(content: Text(e.status == 409 ? avisoCambio : e.mensaje)),
        );
        if (e.status == 409) widget.alCambiar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fotos = ref.watch(evidenciasProvider(widget.solicitudId));
    final lista = fotos.value ?? const <Evidencia>[];
    final cantidad = lista.length;
    final lleno = cantidad >= LimitesEvidencia.maximo;
    final ocupado = _subiendo || _completando || !fotos.hasValue;
    final texto = Theme.of(context).textTheme;
    final secundario = Theme.of(context).colorScheme.onSurfaceVariant;
    return SeccionCotizacion(
      key: const Key('seccion-evidencia'),
      titulo: 'Evidencia del trabajo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sube al menos una foto del trabajo para completar el servicio. '
            'Puedes subir hasta ${LimitesEvidencia.maximo}.',
            style: texto.bodyMedium,
          ),
          const SizedBox(height: QpEspacio.e3),
          if (fotos.hasError && !fotos.hasValue)
            Column(
              key: const Key('error-evidencias'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('No pudimos cargar tus fotos.'),
                TextButton(
                  onPressed: _recargarFotos,
                  child: const Text('Reintentar'),
                ),
              ],
            )
          else if (!fotos.hasValue)
            const Center(child: CircularProgressIndicator())
          else if (lista.isNotEmpty)
            GaleriaEvidencias(
              solicitudId: widget.solicitudId,
              evidencias: lista,
            ),
          const SizedBox(height: QpEspacio.e2),
          Text(
            '$cantidad de ${LimitesEvidencia.maximo} fotos',
            key: const Key('contador-fotos'),
            style: texto.bodySmall?.copyWith(color: secundario),
          ),
          if (_subiendo) ...[
            const SizedBox(height: QpEspacio.e3),
            Semantics(
              label: 'Subiendo foto',
              child: LinearProgressIndicator(
                key: const Key('progreso-subida'),
                value: _avance,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: QpEspacio.e2),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                key: const Key('error-foto'),
                style: texto.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: QpEspacio.e3),
          if (lleno)
            Text(
              'Llegaste al máximo de ${LimitesEvidencia.maximo} fotos.',
              key: const Key('maximo-fotos'),
              style: texto.bodySmall?.copyWith(color: secundario),
            )
          else
            Wrap(
              spacing: QpEspacio.e2,
              runSpacing: QpEspacio.e2,
              children: [
                OutlinedButton.icon(
                  key: const Key('boton-tomar-foto'),
                  onPressed: ocupado ? null : () => _subir(OrigenFoto.camara),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Tomar foto'),
                ),
                OutlinedButton.icon(
                  key: const Key('boton-elegir-foto'),
                  onPressed: ocupado ? null : () => _subir(OrigenFoto.galeria),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Elegir de la galería'),
                ),
              ],
            ),
          const SizedBox(height: QpEspacio.e4),
          FilledButton.icon(
            key: const Key('boton-completar'),
            onPressed: ocupado || cantidad == 0 ? null : _completar,
            icon: _completando
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.task_alt_rounded),
            label: const Text('Marcar como completado'),
          ),
          if (cantidad == 0 && fotos.hasValue) ...[
            const SizedBox(height: QpEspacio.e2),
            Text(
              'Sube al menos una foto para completar.',
              key: const Key('ayuda-completar'),
              textAlign: TextAlign.center,
              style: texto.bodySmall?.copyWith(color: secundario),
            ),
          ],
        ],
      ),
    );
  }
}

class _Completado extends ConsumerWidget {
  const _Completado(this.solicitud);

  final Solicitud solicitud;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref.watch(evidenciasProvider(solicitud.id)).value;
    final fin = solicitud.completadaEn;
    return SeccionCotizacion(
      key: const Key('servicio-completado'),
      titulo: 'Servicio completado',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            fin == null
                ? 'Completaste el servicio. Falta que el cliente lo pague.'
                : 'Lo completaste el ${fechaCorta(fin.toLocal())}. Falta que '
                      'el cliente lo pague.',
          ),
          if (lista != null && lista.isNotEmpty) ...[
            const SizedBox(height: QpEspacio.e3),
            GaleriaEvidencias(solicitudId: solicitud.id, evidencias: lista),
          ],
        ],
      ),
    );
  }
}
