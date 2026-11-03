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
import '../widgets/calificacion_recibida.dart';
import '../widgets/tarjeta_solicitud.dart';

/// Filtro del historial. El contrato acepta un solo `status`, así que cada
/// filtro es una consulta paginada aparte.
enum FiltroHistorial {
  completados(
    'Completados',
    EstadoSolicitud.completado,
    'Cuando termines un servicio, aparecerá aquí.',
  ),
  pagados(
    'Pagados',
    EstadoSolicitud.pagado,
    'Cuando el cliente pague un servicio, aparecerá aquí con su calificación.',
  ),
  cancelados(
    'Cancelados',
    EstadoSolicitud.cancelado,
    'Si se cancela un servicio tuyo, aparecerá aquí.',
  );

  const FiltroHistorial(this.etiqueta, this.estado, this.mensajeVacio);

  final String etiqueta;
  final EstadoSolicitud estado;
  final String mensajeVacio;
}

/// Historial del técnico, desde Cuenta (SCRUM-101), con
/// `GET /v1/technicians/me/service-requests` (service-request 1.10.0). Muestra
/// la calificación recibida cuando el servicio está pagado (RN-R3). Solo los
/// completados abren su detalle: en los demás estados la API responde 403
/// (RN-SR13).
class HistorialTecnicoPage extends ConsumerStatefulWidget {
  const HistorialTecnicoPage({super.key});

  @override
  ConsumerState<HistorialTecnicoPage> createState() =>
      _HistorialTecnicoPageState();
}

class _HistorialTecnicoPageState extends ConsumerState<HistorialTecnicoPage> {
  FiltroHistorial _filtro = FiltroHistorial.completados;
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
        .listen((_) => unawaited(_cargar(silencioso: true)));
  }

  /// Carga la primera página del filtro actual. [silencioso] la recarga sin
  /// quitar la lista que se ve.
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

  void _filtrar(FiltroHistorial filtro) {
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
      appBar: AppBar(title: const Text('Historial')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                QpEspacio.pantalla,
                QpEspacio.e2,
                QpEspacio.pantalla,
                QpEspacio.e3,
              ),
              // Wrap y no SegmentedButton: con texto grande pasa a otra línea.
              child: Wrap(
                key: const Key('filtro-historial'),
                spacing: QpEspacio.e2,
                runSpacing: QpEspacio.e2,
                children: [
                  for (final f in FiltroHistorial.values)
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
      return const IndicadorCarga(etiqueta: 'Cargando tu historial');
    }
    if (_error case final error?) {
      return Center(
        child: SingleChildScrollView(
          child: VistaError(
            key: const Key('error-historial'),
            error: error,
            titulo: 'No pudimos cargar tu historial.',
            alReintentar: _cargar,
          ),
        ),
      );
    }
    if (_servicios.isEmpty) {
      // Con RefreshIndicator también se puede recargar la lista vacía.
      return RefreshIndicator(
        onRefresh: () => _cargar(silencioso: true),
        child: LayoutBuilder(
          builder: (context, restricciones) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: restricciones.maxHeight),
              child: Center(
                child: VistaEstado(
                  key: const Key('historial-vacio'),
                  icono: Icons.history_rounded,
                  titulo:
                      'No tienes servicios ${_filtro.etiqueta.toLowerCase()}.',
                  mensaje: _filtro.mensajeVacio,
                ),
              ),
            ),
          ),
        ),
      );
    }
    final hayMas = _servicios.length < _total;
    return RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      child: ListView(
        key: const Key('lista-historial'),
        padding: const EdgeInsets.fromLTRB(
          QpEspacio.pantalla,
          0,
          QpEspacio.pantalla,
          QpEspacio.e8,
        ),
        children: [
          Text(
            _total == 1 ? '1 servicio' : '$_total servicios',
            key: const Key('total-historial'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: QpEspacio.e2),
          for (final s in _servicios)
            Padding(
              padding: const EdgeInsets.only(bottom: QpEspacio.e2),
              child: TarjetaSolicitud(
                key: Key('historial-${s.id}'),
                servicio: nombres[s.categoriaId] ?? 'Servicio',
                descripcion: s.descripcion,
                estado: s.estado,
                fecha: s.asignadaEn,
                alTocar: s.estado == EstadoSolicitud.completado
                    ? () => context.push(Rutas.solicitudAsignada(s.id))
                    : null,
                acciones: [
                  if (s.estado == EstadoSolicitud.pagado)
                    CalificacionRecibida(s.puntaje),
                ],
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
