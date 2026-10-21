import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/fechas.dart';
import '../../../../shared/widgets/boton_principal.dart';
import '../../data/compartir_archivo.dart';
import '../../data/repositorio_pagos.dart';
import '../../domain/pago.dart';

/// Comprobante del pago aprobado (RF-24, SCRUM-494; payments 1.1.0): los
/// datos del servicio, el monto, la fecha y el pagador (con el NIT si facturó
/// como empresa). «Compartir PDF» descarga el PDF del servidor y abre el menú
/// del sistema para guardarlo o enviarlo.
class ComprobantePage extends ConsumerStatefulWidget {
  const ComprobantePage({required this.pagoId, super.key});

  final String pagoId;

  @override
  ConsumerState<ComprobantePage> createState() => _ComprobantePageState();
}

class _ComprobantePageState extends ConsumerState<ComprobantePage> {
  var _descargando = false;

  Future<void> _compartirPdf(Comprobante comprobante) async {
    setState(() => _descargando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pdf = await ref
          .read(repositorioPagosProvider)
          .comprobantePdf(widget.pagoId);
      await ref.read(compartirArchivoProvider)(
        bytes: pdf,
        nombre: comprobante.archivoPdf,
        tipo: 'application/pdf',
      );
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Comprobante de pago')),
    body: SafeArea(
      child: ref
          .watch(comprobanteProvider(widget.pagoId))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              key: const Key('error-comprobante'),
              child: Padding(
                padding: const EdgeInsets.all(QpEspacio.pantalla),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      e is AppException
                          ? e.mensaje
                          : 'No pudimos cargar el comprobante.',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(comprobanteProvider(widget.pagoId)),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
            data: (comprobante) => ListView(
              padding: const EdgeInsets.all(QpEspacio.pantalla),
              children: [
                _Encabezado(comprobante: comprobante),
                const SizedBox(height: QpEspacio.e4),
                const _SinValidezFiscal(),
                const SizedBox(height: QpEspacio.e5),
                _Seccion(
                  titulo: 'Pagador',
                  filas: [
                    ('Nombre o razón social', comprobante.pagador.nombre),
                    (
                      'Documento',
                      '${comprobante.pagador.tipoDocumento.valor} '
                          '${comprobante.pagador.numeroDocumento}',
                    ),
                    ('Correo', comprobante.pagador.correo),
                  ],
                ),
                const SizedBox(height: QpEspacio.e4),
                _Seccion(
                  titulo: 'Servicio',
                  filas: [
                    ('Concepto', comprobante.concepto),
                    ('Pago', comprobante.pagoId),
                    ('Medio de pago', 'Tarjeta (token de la pasarela)'),
                  ],
                ),
                const SizedBox(height: QpEspacio.e5),
                BotonPrincipal(
                  key: const Key('compartir-pdf'),
                  texto: 'Compartir PDF',
                  icono: Icons.picture_as_pdf_rounded,
                  cargando: _descargando,
                  alPresionar: () => _compartirPdf(comprobante),
                ),
              ],
            ),
          ),
    ),
  );
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.comprobante});

  final Comprobante comprobante;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          comprobante.numero,
          key: const Key('numero-comprobante'),
          style: tema.textTheme.titleMedium,
        ),
        Text(
          'Emitido el ${fechaCorta(comprobante.emitidoEn.toLocal())}',
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: QpEspacio.e3),
        Text('Total pagado', style: tema.textTheme.bodyMedium),
        Text(
          '${comprobante.monto.formatear()} ${comprobante.moneda}',
          key: const Key('total-comprobante'),
          style: tema.textTheme.headlineMedium,
        ),
      ],
    );
  }
}

class _SinValidezFiscal extends StatelessWidget {
  const _SinValidezFiscal();

  @override
  Widget build(BuildContext context) {
    final estados = context.estados;
    return DecoratedBox(
      key: const Key('sin-validez-fiscal'),
      decoration: BoxDecoration(
        color: estados.avisoFondo,
        borderRadius: BorderRadius.circular(QpRadio.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(QpEspacio.e3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: estados.aviso, size: 20),
            const SizedBox(width: QpEspacio.e2),
            Expanded(
              child: Text(
                'Documento sin validez fiscal: es el comprobante de tu pago, '
                'no una factura electrónica.',
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
  const _Seccion({required this.titulo, required this.filas});

  final String titulo;
  final List<(String, String)> filas;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(titulo, style: tema.textTheme.titleMedium),
        ),
        const Divider(),
        for (final (etiqueta, valor) in filas)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: QpEspacio.e1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
                SelectableText(valor, style: tema.textTheme.bodyLarge),
              ],
            ),
          ),
      ],
    );
  }
}
