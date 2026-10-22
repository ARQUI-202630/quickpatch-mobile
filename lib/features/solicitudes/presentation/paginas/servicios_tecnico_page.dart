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
import '../../../../shared/widgets/vista_error.dart';
import '../../../../shared/widgets/vista_estado.dart';
import '../../data/repositorio_solicitudes.dart';
import '../../domain/modelos.dart';
import '../widgets/tarjeta_solicitud.dart';

/// Filtro de la lista del técnico. El contrato acepta un solo `status`;
/// los demás estados se ven en «Todos».
enum FiltroServicios {
  todos('Todos', null),
  asignados('Asignados', EstadoSolicitud.asignado),
  enProgreso('En progreso', EstadoSolicitud.enProgreso),
  completados('Completados', EstadoSolicitud.completado);

  const FiltroServicios(this.etiqueta, this.estado);

  final String etiqueta;
  final EstadoSolicitud? estado;
}

/// Servicios asignados al técnico (RF-17, SCRUM-92), con
/// `GET /v1/technicians/me/service-requests` (service-request 1.2.0). La
/// lista no trae dirección ni cliente (RN-SR13): al tocar un servicio se abre
/// su detalle. Se recarga cuando el canal en tiempo real avisa un cambio de
/// estado y al deslizar.
class ServiciosTecnicoPage extends ConsumerStatefulWidget {
  const ServiciosTecnicoPage({super.key, this.encabezado, this.alRecargar});

  /// Contenido arriba de la lista que arma el shell, por ejemplo la oferta
  /// pendiente (SCRUM-80). Así esta feature no importa otras.
  final Widget? encabezado;

  /// Se llama también al deslizar para recargar, para el [encabezado].
  final VoidCallback? alRecargar;

  @override
  ConsumerState<ServiciosTecnicoPage> createState() =>
      _ServiciosTecnicoPageState();
}

class _ServiciosTecnicoPageState extends ConsumerState<ServiciosTecnicoPage> {
  FiltroServicios _filtro = FiltroServicios.todos;
  List<ServicioTecnico> _servicios = const [];
  int _pagina = 0;
  int _total = 0;
  bool _cargando = true;
  bool _cargandoMas = false;
  Object? _error;
  CanalTiempoReal? _canal;
  StreamSubscription<MensajeTiempoReal>? _avisos;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    unawaited(_avisos?.cancel());
    super.dispose();
  }

  RepositorioSolicitudes get _repositorio =>
      ref.read(repositorioSolicitudesProvider);

  /// Se suscribe al canal actual; cambia si la sesión crea uno nuevo.
  void _escuchar(CanalTiempoReal canal) {
    if (identical(canal, _canal)) return;
    unawaited(_avisos?.cancel());
    _canal = canal;
    _avisos = canal.avisos
        .where((m) => m.tipo == MensajeTiempoReal.cambioDeEstado)
        .listen(_alCambiarEstado);
  }

  /// El aviso sale de ServiceRequest después de guardar el cambio
  /// (SCRUM-466), así que una recarga ya trae el dato.
  void _alCambiarEstado(MensajeTiempoReal aviso) {
    unawaited(_cargar(silencioso: true));
  }

  /// Carga la primera página del filtro actual. [silencioso] la recarga sin
  /// quitar la lista que se ve (aviso en tiempo real o deslizar).
  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    final filtro = _filtro;
    try {
      final pagina = await _repositorio.serviciosDelTecnico(
        estado: filtro.estado,
      );
      if (!mounted || filtro != _filtro) return;
      setState(() {
        _servicios = pagina.servicios;
        _pagina = pagina.pagina;
        _total = pagina.total;
        _error = null;
      });
    } on AppException catch (e) {
      if (!mounted || filtro != _filtro) return;
      // Al recargar en silencio, un fallo no borra lo que ya se ve.
      if (silencioso && _servicios.isNotEmpty) {
        _avisar(e.mensaje);
      } else {
        setState(() => _error = e);
      }
    } finally {
      if (mounted && filtro == _filtro) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarMas() async {
    setState(() => _cargandoMas = true);
    final filtro = _filtro;
    try {
      final pagina = await _repositorio.serviciosDelTecnico(
        estado: filtro.estado,
        pagina: _pagina + 1,
      );
      if (!mounted || filtro != _filtro) return;
      setState(() {
        _servicios = [..._servicios, ...pagina.servicios];
        _pagina = pagina.pagina;
        _total = pagina.total;
      });
    } on AppException catch (e) {
      _avisar(e.mensaje);
    } finally {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  /// Deslizar para recargar: la lista y el encabezado.
  Future<void> _recargar() {
    widget.alRecargar?.call();
    return _cargar(silencioso: true);
  }

  void _filtrar(FiltroServicios filtro) {
    if (filtro == _filtro) return;
    setState(() => _filtro = filtro);
    _cargar();
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    _escuchar(ref.watch(canalTiempoRealProvider));
    // Nombres de categoría; sin catálogo la lista se muestra igual.
    final categorias = ref.watch(categoriasProvider).value ?? const [];
    final nombres = {for (final c in categorias) c.id: c.nombre};
    return Scaffold(
      appBar: AppBar(title: const Text('Servicios')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.encabezado case final encabezado?)
              // Con texto grande, el encabezado se desplaza y no tapa la lista.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    QpEspacio.pantalla,
                    QpEspacio.e2,
                    QpEspacio.pantalla,
                    0,
                  ),
                  child: encabezado,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                QpEspacio.pantalla,
                QpEspacio.e2,
                QpEspacio.pantalla,
                QpEspacio.e3,
              ),
              // Wrap y no SegmentedButton: con texto grande pasa a otra línea.
              child: Wrap(
                key: const Key('filtro-servicios'),
                spacing: QpEspacio.e2,
                runSpacing: QpEspacio.e2,
                children: [
                  for (final f in FiltroServicios.values)
                    ChoiceChip(
                      key: Key('filtro-${f.name}'),
                      label: Text(f.etiqueta),
                      selected: f == _filtro,
                      onSelected: (_) => _filtrar(f),
                    ),
                ],
              ),
            ),
            Expanded(child: _contenido(nombres)),
          ],
        ),
      ),
    );
  }

  Widget _contenido(Map<String, String> nombres) {
    if (_cargando) {
      return const IndicadorCarga(etiqueta: 'Cargando tus servicios');
    }
    if (_error case final error?) {
      return Center(
        child: SingleChildScrollView(
          child: VistaError(
            key: const Key('error-servicios'),
            error: error,
            titulo: 'No pudimos cargar tus servicios.',
            alReintentar: _cargar,
          ),
        ),
      );
    }
    if (_servicios.isEmpty) {
      final todos = _filtro == FiltroServicios.todos;
      // Con RefreshIndicator también se puede recargar la lista vacía.
      return RefreshIndicator(
        onRefresh: _recargar,
        child: LayoutBuilder(
          builder: (context, restricciones) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: restricciones.maxHeight),
              child: Center(
                child: VistaEstado(
                  key: const Key('servicios-vacio'),
                  icono: Icons.work_outline_rounded,
                  titulo: todos
                      ? 'Aún no tienes servicios asignados.'
                      : 'No tienes servicios '
                            '${_filtro.etiqueta.toLowerCase()}.',
                  mensaje: todos
                      ? 'Cuando te asignen uno, aparecerá aquí y te '
                            'avisaremos.'
                      : null,
                ),
              ),
            ),
          ),
        ),
      );
    }
    final hayMas = _servicios.length < _total;
    return RefreshIndicator(
      onRefresh: _recargar,
      child: ListView(
        key: const Key('lista-servicios'),
        padding: const EdgeInsets.fromLTRB(
          QpEspacio.pantalla,
          0,
          QpEspacio.pantalla,
          QpEspacio.e8,
        ),
        children: [
          Text(
            _total == 1 ? '1 servicio' : '$_total servicios',
            key: const Key('total-servicios'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: QpEspacio.e2),
          for (final s in _servicios)
            Padding(
              padding: const EdgeInsets.only(bottom: QpEspacio.e2),
              child: TarjetaSolicitud(
                key: Key('servicio-${s.id}'),
                servicio: nombres[s.categoriaId] ?? 'Servicio',
                descripcion: s.descripcion,
                estado: s.estado,
                fecha: s.asignadaEn,
                alTocar: () => context.push(Rutas.solicitudAsignada(s.id)),
              ),
            ),
          if (hayMas)
            Padding(
              padding: const EdgeInsets.only(top: QpEspacio.e2),
              child: OutlinedButton(
                key: const Key('boton-cargar-mas'),
                onPressed: _cargandoMas ? null : _cargarMas,
                child: Text(_cargandoMas ? 'Cargando…' : 'Cargar más'),
              ),
            ),
        ],
      ),
    );
  }
}
