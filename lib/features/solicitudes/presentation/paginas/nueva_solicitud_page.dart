import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/catalogo/categoria.dart';
import '../../../../core/catalogo/repositorio_catalogo.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/session/controlador_sesion.dart';
import '../../../../core/session/rol_usuario.dart';
import '../../../../shared/widgets/boton_principal.dart';
import '../../../../shared/widgets/confirmar_salida.dart';
import '../../../../shared/widgets/icono_categoria.dart';
import '../../../../shared/widgets/mensaje_error.dart';
import '../../../../shared/widgets/vista_error.dart';
import '../../../../shared/widgets/vista_estado.dart';
import '../../data/proveedor_ubicacion.dart';
import '../../data/repositorio_solicitudes.dart';
import '../../domain/modelos.dart';
import '../widgets/confirmar_ubicacion.dart';

/// Nueva solicitud de servicio (RF-07, SCRUM-27). El cliente elige la
/// categoría, describe el problema, escribe la dirección y, de preferencia,
/// comparte su ubicación. Sin ella, la app ubica la dirección y le pide
/// confirmarla (SCRUM-457, ADR-024). Contratos: `POST /v1/service-requests`
/// y `POST /v1/service-requests/location-preview` (1.3.0).
///
/// El `empresa_contacto` la crea a nombre de su empresa con el nombre de la
/// sede, opcional (RF-08, SCRUM-74, service-request 1.9.0).
class NuevaSolicitudPage extends ConsumerStatefulWidget {
  const NuevaSolicitudPage({this.categoriaInicial, super.key});

  /// Categoría elegida desde el inicio; se ignora si Catalog ya no la ofrece.
  final String? categoriaInicial;

  @override
  ConsumerState<NuevaSolicitudPage> createState() => _NuevaSolicitudPageState();
}

class _NuevaSolicitudPageState extends ConsumerState<NuevaSolicitudPage> {
  final _formulario = GlobalKey<FormState>();
  final _descripcion = TextEditingController();
  final _direccion = TextEditingController();
  final _sede = TextEditingController();
  late String? _categoriaId = widget.categoriaInicial;
  Ubicacion? _ubicacion;
  bool _ubicando = false;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _descripcion.dispose();
    _direccion.dispose();
    _sede.dispose();
    super.dispose();
  }

  bool get _esEmpresa =>
      ref.read(controladorSesionProvider).value?.usuario.rol ==
      RolUsuario.empresaContacto;

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
    } on Exception {
      if (mounted) {
        setState(() => _error = 'No pudimos obtener tu ubicación.');
      }
    } finally {
      if (mounted) setState(() => _ubicando = false);
    }
  }

  /// Con GPS crea la solicitud con ese punto. Sin GPS, primero ubica la
  /// dirección y le pregunta al cliente «¿Es aquí?» (service-request 1.3.0,
  /// ADR-024): la localidad decide qué técnicos reciben la oferta (RN-M9).
  Future<void> _enviar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final ubicacion = _ubicacion ?? await _confirmarDireccion();
      if (ubicacion == null || !mounted) return;
      final solicitud = await ref
          .read(repositorioSolicitudesProvider)
          .crear(
            NuevaSolicitud(
              categoriaId: _categoriaId!,
              descripcion: _descripcion.text,
              ubicacion: ubicacion,
              direccion: _direccion.text,
              sede: _esEmpresa ? _sede.text : null,
            ),
          );
      if (mounted) context.go(Rutas.detalleSolicitud(solicitud.id));
    } on AppException catch (e) {
      if (mounted) setState(() => _error = _mensajeDe(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Ubica la dirección escrita y la muestra para confirmar. Devuelve el
  /// punto confirmado, o `null` si el cliente dice que no es ahí.
  Future<Ubicacion?> _confirmarDireccion() async {
    final vista = await ref
        .read(repositorioSolicitudesProvider)
        .vistaPrevia(_direccion.text);
    if (!mounted) return null;
    // Mientras el cliente decide, el botón no está cargando.
    setState(() => _enviando = false);
    final confirmado = await confirmarUbicacion(context, vista);
    if (!mounted) return null;
    if (confirmado) {
      setState(() => _enviando = true);
      return vista.ubicacion;
    }
    if (mounted) {
      setState(
        () => _error =
            'Toca «Usar mi ubicación» para que el técnico llegue al lugar '
            'correcto.',
      );
    }
    return null;
  }

  String _mensajeDe(AppException e) {
    if (e.esProblema('direccion-no-encontrada')) {
      return 'No encontramos esa dirección en Bogotá. Revisa la calle y el '
          'número, o toca «Usar mi ubicación».';
    }
    if (e.esProblema('ubicacion-fuera-de-cobertura')) {
      return 'Esa ubicación queda fuera de Bogotá, donde trabaja QUICKPATCH. '
          'Revisa la dirección o toca «Usar mi ubicación».';
    }
    return [
      e.mensaje,
      for (final campo in e.erroresCampo) '• ${campo.mensaje}',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) => ConfirmarSalida.conTextos(
    controladores: [_descripcion, _direccion, _sede],
    child: _contenido(context),
  );

  Widget _contenido(BuildContext context) {
    final categorias = ref.watch(categoriasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva solicitud')),
      body: SafeArea(
        child: categorias.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Cargando categorías',
            ),
          ),
          error: (e, _) => Center(
            child: SingleChildScrollView(
              child: VistaError(
                error: e,
                titulo: 'No pudimos cargar las categorías.',
                alReintentar: () => ref.invalidate(categoriasProvider),
              ),
            ),
          ),
          data: (lista) => lista.isEmpty
              ? const Center(
                  child: VistaEstado(
                    icono: Icons.category_outlined,
                    titulo:
                        'Todavía no hay categorías de servicio disponibles.',
                  ),
                )
              : _formularioCon(context, lista),
        ),
      ),
    );
  }

  Widget _formularioCon(BuildContext context, List<Categoria> lista) {
    if (!lista.any((c) => c.id == _categoriaId)) _categoriaId = null;
    final estados = context.estados;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        QpEspacio.pantalla,
        QpEspacio.e2,
        QpEspacio.pantalla,
        QpEspacio.e8,
      ),
      child: Form(
        key: _formulario,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Paso(1, 'Tipo de servicio'),
            DropdownButtonFormField<String>(
              key: const Key('campo-categoria'),
              initialValue: _categoriaId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo de servicio'),
              items: [
                for (final categoria in lista)
                  DropdownMenuItem(
                    value: categoria.id,
                    child: Row(
                      children: [
                        Icon(iconoCategoria(categoria.nombre), size: 20),
                        const SizedBox(width: QpEspacio.e3),
                        Flexible(
                          child: Text(
                            categoria.nombre,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: (valor) => setState(() => _categoriaId = valor),
              validator: (valor) =>
                  valor == null ? 'Elige el tipo de servicio.' : null,
            ),
            const SizedBox(height: QpEspacio.e6),
            const _Paso(2, 'Cuéntanos qué pasa'),
            TextFormField(
              key: const Key('campo-descripcion'),
              controller: _descripcion,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: '¿Qué necesitas?',
                hintText: 'Describe el problema (mínimo 10 caracteres)',
                alignLabelWithHint: true,
              ),
              validator: (valor) => (valor ?? '').trim().length < 10
                  ? 'Describe el problema con al menos 10 caracteres.'
                  : null,
            ),
            const SizedBox(height: QpEspacio.e4),
            const _Paso(3, '¿Dónde es?'),
            if (_esEmpresa) ...[
              TextFormField(
                key: const Key('campo-sede'),
                controller: _sede,
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Sede (opcional)',
                  hintText: 'Por ejemplo, Sede Chapinero',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: (valor) {
                  final sede = (valor ?? '').trim();
                  return sede.isNotEmpty && sede.length < 2
                      ? 'Escribe el nombre de la sede (mínimo 2 caracteres).'
                      : null;
                },
              ),
              const SizedBox(height: QpEspacio.e2),
            ],
            TextFormField(
              key: const Key('campo-direccion'),
              controller: _direccion,
              maxLength: 255,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                hintText: 'Calle, número, torre, apartamento…',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              validator: (valor) => (valor ?? '').trim().length < 5
                  ? 'Escribe la dirección (mínimo 5 caracteres).'
                  : null,
            ),
            const SizedBox(height: QpEspacio.e2),
            OutlinedButton.icon(
              key: const Key('boton-ubicacion'),
              onPressed: _ubicando ? null : _ubicar,
              style: _ubicacion == null
                  ? null
                  : OutlinedButton.styleFrom(
                      foregroundColor: estados.exito,
                      backgroundColor: estados.exitoFondo,
                      side: BorderSide(color: estados.exito),
                    ),
              icon: _ubicando
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _ubicacion == null
                          ? Icons.my_location_rounded
                          : Icons.check_circle_rounded,
                    ),
              label: Text(
                _ubicacion == null
                    ? 'Usar mi ubicación'
                    : 'Ubicación: ${_ubicacion!.latitud.toStringAsFixed(5)}, '
                          '${_ubicacion!.longitud.toStringAsFixed(5)}',
              ),
            ),
            const SizedBox(height: QpEspacio.e1),
            Text(
              _ubicacion == null
                  ? 'La usamos para encontrar técnicos cerca de ti. Si no la '
                        'compartes, ubicamos la dirección en el mapa.'
                  : 'La usamos para encontrar técnicos cerca de ti.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: QpEspacio.e4),
              MensajeError(_error!, key: const Key('mensaje-error')),
            ],
            const SizedBox(height: QpEspacio.e6),
            BotonPrincipal(
              key: const Key('boton-enviar'),
              texto: 'Solicitar servicio',
              icono: Icons.send_rounded,
              cargando: _enviando,
              alPresionar: _enviar,
            ),
          ],
        ),
      ),
    );
  }
}

/// Encabezado numerado de cada paso del formulario.
class _Paso extends StatelessWidget {
  const _Paso(this.numero, this.titulo);

  final int numero;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: QpEspacio.e3),
      child: Semantics(
        header: true,
        label: 'Paso $numero: $titulo',
        excludeSemantics: true,
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: esquema.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 28,
                child: Center(
                  child: Text(
                    '$numero',
                    style: texto.labelLarge?.copyWith(
                      color: esquema.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: QpEspacio.e3),
            Expanded(child: Text(titulo, style: texto.titleSmall)),
          ],
        ),
      ),
    );
  }
}
