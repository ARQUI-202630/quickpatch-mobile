import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/utils/fechas.dart';
import '../../data/repositorio_solicitudes.dart';
import '../../domain/modelos.dart';

/// Miniaturas de las fotos de evidencia (service-request 1.7.0). Cada foto se
/// descarga con el token de la sesión; al tocarla se ve completa con zoom.
class GaleriaEvidencias extends StatelessWidget {
  const GaleriaEvidencias({
    required this.solicitudId,
    required this.evidencias,
    super.key,
  });

  final String solicitudId;
  final List<Evidencia> evidencias;

  static const lado = 96.0;

  @override
  Widget build(BuildContext context) => Wrap(
    key: const Key('galeria-evidencias'),
    spacing: QpEspacio.e2,
    runSpacing: QpEspacio.e2,
    children: [
      for (final (i, e) in evidencias.indexed)
        _Miniatura(
          solicitudId: solicitudId,
          evidencia: e,
          etiqueta: 'Foto ${i + 1} de ${evidencias.length}',
        ),
    ],
  );
}

class _Miniatura extends ConsumerWidget {
  const _Miniatura({
    required this.solicitudId,
    required this.evidencia,
    required this.etiqueta,
  });

  final String solicitudId;
  final Evidencia evidencia;
  final String etiqueta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clave = (solicitudId: solicitudId, evidenciaId: evidencia.id);
    final archivo = ref.watch(archivoEvidenciaProvider(clave));
    final esquema = Theme.of(context).colorScheme;
    final contenido = archivo.when(
      loading: () => const Center(
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) =>
          Icon(Icons.broken_image_outlined, color: esquema.onSurfaceVariant),
      data: (bytes) => Image.memory(
        bytes,
        fit: BoxFit.cover,
        cacheWidth: 300,
        // Un archivo que no es imagen no rompe la pantalla.
        errorBuilder: (_, _, _) =>
            Icon(Icons.broken_image_outlined, color: esquema.onSurfaceVariant),
      ),
    );
    return Semantics(
      button: true,
      label: '$etiqueta, subida el ${fechaCorta(evidencia.subidaEn.toLocal())}',
      child: Material(
        key: Key('evidencia-${evidencia.id}'),
        color: esquema.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(QpRadio.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: switch (archivo) {
            AsyncData(:final value) => () => _verCompleta(context, value),
            AsyncError() => () => ref.invalidate(
              archivoEvidenciaProvider(clave),
            ),
            _ => null,
          },
          child: SizedBox.square(
            dimension: GaleriaEvidencias.lado,
            child: contenido,
          ),
        ),
      ),
    );
  }

  void _verCompleta(BuildContext context, Uint8List bytes) => showDialog<void>(
    context: context,
    builder: (contexto) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: Image.memory(
                  bytes,
                  key: const Key('foto-completa'),
                  semanticLabel: etiqueta,
                ),
              ),
            ),
          ),
          SafeArea(
            child: IconButton(
              key: const Key('cerrar-foto'),
              tooltip: 'Cerrar',
              color: Colors.white,
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(contexto).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}
