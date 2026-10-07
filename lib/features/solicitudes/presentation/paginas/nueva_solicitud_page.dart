import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../../../core/errors/app_exception.dart';
import '../../data/proveedor_ubicacion.dart';
import '../../data/repositorio_solicitudes.dart';
import '../../domain/modelos.dart';

/// Nueva solicitud de servicio (RF-07, SCRUM-27). El cliente elige la
/// categoría, describe el problema, comparte su ubicación y escribe la
/// dirección. Contrato: `POST /v1/service-requests`.
class NuevaSolicitudPage extends ConsumerStatefulWidget {
  const NuevaSolicitudPage({super.key});

  @override
  ConsumerState<NuevaSolicitudPage> createState() => _NuevaSolicitudPageState();
}

class _NuevaSolicitudPageState extends ConsumerState<NuevaSolicitudPage> {
  final _formulario = GlobalKey<FormState>();
  final _descripcion = TextEditingController();
  final _direccion = TextEditingController();
  String? _categoriaId;
  Ubicacion? _ubicacion;
  bool _ubicando = false;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _descripcion.dispose();
    _direccion.dispose();
    super.dispose();
  }

  Future<void> _ubicar() async {
    setState(() {
      _ubicando = true;
      _error = null;
    });
    try {
      final ubicacion = await ref.read(proveedorUbicacionProvider).actual();
      if (mounted) setState(() => _ubicacion = ubicacion);
    } on UbicacionNoDisponible catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _ubicando = false);
    }
  }

  Future<void> _enviar() async {
    if (!_formulario.currentState!.validate()) return;
    if (_ubicacion == null) {
      setState(() => _error = 'Comparte tu ubicación para continuar.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final solicitud = await ref
          .read(repositorioSolicitudesProvider)
          .crear(
            NuevaSolicitud(
              categoriaId: _categoriaId!,
              descripcion: _descripcion.text,
              ubicacion: _ubicacion!,
              direccion: _direccion.text,
            ),
          );
      if (mounted) context.go(Rutas.detalleSolicitud(solicitud.id));
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _error = [
            e.mensaje,
            for (final campo in e.erroresCampo) '• ${campo.mensaje}',
          ].join('\n');
        });
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categorias = ref.watch(categoriasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva solicitud')),
      body: SafeArea(
        child: categorias.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorCarga(
            mensaje: e is AppException
                ? e.mensaje
                : 'No pudimos cargar las categorías.',
            alReintentar: () => ref.invalidate(categoriasProvider),
          ),
          data: (lista) => lista.isEmpty
              ? const _ErrorCarga(
                  mensaje: 'Todavía no hay categorías de servicio disponibles.',
                )
              : _formularioCon(context, lista),
        ),
      ),
    );
  }

  Widget _formularioCon(BuildContext context, List<Categoria> lista) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formulario,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: const Key('campo-categoria'),
              initialValue: _categoriaId,
              decoration: const InputDecoration(labelText: 'Tipo de servicio'),
              items: [
                for (final categoria in lista)
                  DropdownMenuItem(
                    value: categoria.id,
                    child: Text(categoria.nombre),
                  ),
              ],
              onChanged: (valor) => setState(() => _categoriaId = valor),
              validator: (valor) =>
                  valor == null ? 'Elige el tipo de servicio.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('campo-descripcion'),
              controller: _descripcion,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: '¿Qué necesitas?',
                hintText: 'Describe el problema (mínimo 10 caracteres)',
              ),
              validator: (valor) => (valor ?? '').trim().length < 10
                  ? 'Describe el problema con al menos 10 caracteres.'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('campo-direccion'),
              controller: _direccion,
              maxLength: 255,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                hintText: 'Calle, número, torre, apartamento…',
              ),
              validator: (valor) => (valor ?? '').trim().length < 5
                  ? 'Escribe la dirección (mínimo 5 caracteres).'
                  : null,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('boton-ubicacion'),
              onPressed: _ubicando ? null : _ubicar,
              icon: _ubicando
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                _ubicacion == null
                    ? 'Usar mi ubicación'
                    : 'Ubicación: ${_ubicacion!.latitud.toStringAsFixed(5)}, '
                          '${_ubicacion!.longitud.toStringAsFixed(5)}',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                key: const Key('mensaje-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('boton-enviar'),
              onPressed: _enviando ? null : _enviar,
              child: _enviando
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Solicitar servicio'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCarga extends StatelessWidget {
  const _ErrorCarga({required this.mensaje, this.alReintentar});

  final String mensaje;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(mensaje, textAlign: TextAlign.center),
          if (alReintentar != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: alReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    ),
  );
}
