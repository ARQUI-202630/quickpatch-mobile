import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../../solicitudes/presentation/paginas/detalle_solicitud_page.dart'
    show fechaCorta;
import '../../data/compartir.dart';
import '../../domain/modelos.dart';

/// Muestra la invitación de [nombre] para que el proveedor la comparta con
/// su técnico (SCRUM-98). Identity solo guarda el hash del enlace: esta es la
/// única vez que se ve; si se pierde, el proveedor genera uno nuevo.
Future<void> mostrarInvitacion(
  BuildContext context, {
  required String nombre,
  required Invitacion invitacion,
  required bool esNueva,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      HojaInvitacion(nombre: nombre, invitacion: invitacion, esNueva: esNueva),
);

class HojaInvitacion extends ConsumerStatefulWidget {
  const HojaInvitacion({
    super.key,
    required this.nombre,
    required this.invitacion,
    required this.esNueva,
  });

  final String nombre;
  final Invitacion invitacion;

  /// `true` si es un enlace nuevo de un técnico que ya estaba en el equipo.
  final bool esNueva;

  @override
  ConsumerState<HojaInvitacion> createState() => _HojaInvitacionState();
}

class _HojaInvitacionState extends ConsumerState<HojaInvitacion> {
  bool _copiado = false;

  String get _vence => fechaCorta(widget.invitacion.venceEn.toLocal());

  /// Menú nativo del teléfono: el proveedor elige por dónde enviarlo.
  Future<void> _compartir() => ref.read(compartirProvider)(
    asunto: 'Tu invitación a QUICKPATCH',
    texto:
        'Hola ${widget.nombre}, te agregué a mi equipo en QUICKPATCH. Abre '
        'este enlace para definir tu contraseña; vence el $_vence y sirve una '
        'sola vez: ${widget.invitacion.enlace}',
  );

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: widget.invitacion.enlace));
    if (mounted) setState(() => _copiado = true);
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
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
              child: Text(
                'Invitación de ${widget.nombre}',
                style: texto.titleLarge,
              ),
            ),
            const SizedBox(height: QpEspacio.e2),
            Text(
              widget.esNueva
                  ? 'Generamos un enlace nuevo. Los anteriores ya no funcionan.'
                  : '${widget.nombre} quedó en tu equipo, pendiente de que el '
                        'administrador lo apruebe. Compártele este enlace para '
                        'que defina su contraseña.',
              style: texto.bodyMedium?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: QpEspacio.e4),
            Container(
              key: const Key('enlace-invitacion'),
              padding: const EdgeInsets.all(QpEspacio.e3),
              decoration: BoxDecoration(
                color: esquema.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(QpRadio.md),
              ),
              child: SelectableText(
                widget.invitacion.enlace,
                style: texto.bodySmall,
              ),
            ),
            const SizedBox(height: QpEspacio.e2),
            Text(
              'Vence el $_vence y sirve una sola vez.',
              key: const Key('vence-invitacion'),
              style: texto.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
            const SizedBox(height: QpEspacio.e4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: esquema.primary,
                ),
                const SizedBox(width: QpEspacio.e2),
                Expanded(
                  child: Text(
                    'Por seguridad, este enlace solo se muestra ahora. Si se '
                    'pierde, genera uno nuevo desde tu equipo.',
                    style: texto.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: QpEspacio.e6),
            FilledButton.icon(
              key: const Key('boton-compartir-enlace'),
              onPressed: _compartir,
              icon: const Icon(Icons.share_rounded),
              label: const Text('Compartir enlace'),
            ),
            const SizedBox(height: QpEspacio.e2),
            Semantics(
              liveRegion: true,
              child: OutlinedButton.icon(
                key: const Key('boton-copiar-enlace'),
                onPressed: _copiar,
                icon: Icon(_copiado ? Icons.check_rounded : Icons.copy_rounded),
                label: Text(_copiado ? 'Enlace copiado' : 'Copiar enlace'),
              ),
            ),
            const SizedBox(height: QpEspacio.e2),
            TextButton(
              key: const Key('boton-cerrar-invitacion'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Listo'),
            ),
          ],
        ),
      ),
    );
  }
}
