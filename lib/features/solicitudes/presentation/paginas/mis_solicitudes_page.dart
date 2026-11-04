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
import '../../../../core/session/controlador_sesion.dart';
import '../../../../core/session/rol_usuario.dart';
import '../../../../shared/widgets/vista_error.dart';
import '../../../../shared/widgets/vista_estado.dart';
import '../../data/repositorio_solicitudes.dart';
import '../../domain/modelos.dart';
import '../widgets/tarjeta_solicitud.dart';

/// Filtro de la lista. El contrato acepta un solo `status`; los demás estados
/// se ven en «Todas».
enum FiltroSolicitudes {
  todas('Todas', null),
  buscando('Buscando técnico', EstadoSolicitud.buscandoTecnico),
  asignadas('Asignadas', EstadoSolicitud.asignado),
  completadas('Completadas', EstadoSolicitud.completado),
  canceladas('Canceladas', EstadoSolicitud.cancelado);

  const FiltroSolicitudes(this.etiqueta, this.estado);

  final String etiqueta;
  final EstadoSolicitud? estado;
}

/// Solicitudes del cliente (RF-11) o, para el `empresa_contacto`, las de su
/// empresa (RF-08, RN-SR14; SCRUM-74), con `GET /v1/service-requests`
/// (service-request 1.9.0). Se recarga cuando el canal avisa un cambio de
/// estado y al deslizar. Una solicitud que creó otro usuario de la empresa se
/// abre en solo lectura: las acciones son de quien la creó.
class MisSolicitudesPage extends ConsumerStatefulWidget {
  const MisSolicitudesPage({super.key});

  @override
  ConsumerState<MisSolicitudesPage> createState() => _MisSolicitudesPageState();
}

class _MisSolicitudesPageState extends ConsumerState<MisSolicitudesPage> {
  FiltroSolicitudes _filtro = FiltroSolicitudes.todas;
  List<SolicitudResumen> _solicitudes = const [];
  int _pagina = 0;
  int _total = 0;
  bool _cargando = true;
  bool _cargandoMas = false;
  Object? _error;
  CanalTiempoReal? _canal;
  StreamSubscription<MensajeTiempoReal>? _avisos;

  RepositorioSolicitudes get _repositorio =>
      ref.read(repositorioSolicitudesProvider);

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

  void _escuchar(CanalTiempoReal canal) {
    if (identical(canal, _canal)) return;
    unawaited(_avisos?.cancel());
    _canal = canal;
    _avisos = canal.avisos
        .where((m) => m.tipo == MensajeTiempoReal.cambioDeEstado)
        .listen((_) => _cargar(silencioso: true));
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    final filtro = _filtro;
    try {
      final pagina = await _repositorio.misSolicitudes(estado: filtro.estado);
      if (!mounted || filtro != _filtro) return;
      setState(() {
        _solicitudes = pagina.solicitudes;
        _pagina = pagina.pagina;
        _total = pagina.total;
        _error = null;
      });
    } on AppException catch (e) {
      if (!mounted || filtro != _filtro) return;
      if (silencioso && _solicitudes.isNotEmpty) {
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
      final pagina = await _repositorio.misSolicitudes(
        estado: filtro.estado,
        pagina: _pagina + 1,
      );
      if (!mounted || filtro != _filtro) return;
      setState(() {
        _solicitudes = [..._solicitudes, ...pagina.solicitudes];
        _pagina = pagina.pagina;
        _total = pagina.total;
      });
    } on AppException catch (e) {
      _avisar(e.mensaje);
    } finally {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  void _filtrar(FiltroSolicitudes filtro) {
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
    final usuario = ref.watch(controladorSesionProvider).value?.usuario;
    final esEmpresa = usuario?.rol == RolUsuario.empresaContacto;
    final categorias = ref.watch(categoriasProvider).value ?? const [];
    final nombres = {for (final c in categorias) c.id: c.nombre};
    return Scaffold(
      appBar: AppBar(
        title: Text(esEmpresa ? 'Solicitudes de la empresa' : 'Solicitudes'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('boton-nueva-solicitud'),
        onPressed: () => context.push(Rutas.nuevaSolicitud),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva solicitud'),
      ),
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
              child: Wrap(
                key: const Key('filtro-solicitudes'),
                spacing: QpEspacio.e2,
                runSpacing: QpEspacio.e2,
                children: [
                  for (final f in FiltroSolicitudes.values)
                    ChoiceChip(
                      key: Key('filtro-${f.name}'),
                      label: Text(f.etiqueta),
                      selected: f == _filtro,
                      onSelected: (_) => _filtrar(f),
                    ),
                ],
              ),
            ),
            Expanded(child: _contenido(nombres, usuario?.userId)),
          ],
        ),
      ),
    );
  }

  Widget _contenido(Map<String, String> nombres, String? yo) {
    if (_cargando) {
      return const IndicadorCarga(etiqueta: 'Cargando tus solicitudes');
    }
    if (_error case final error?) {
      return Center(
        child: SingleChildScrollView(
          child: VistaError(
            key: const Key('error-solicitudes'),
            error: error,
            titulo: 'No pudimos cargar tus solicitudes.',
            alReintentar: _cargar,
          ),
        ),
      );
    }
    if (_solicitudes.isEmpty) {
      final todas = _filtro == FiltroSolicitudes.todas;
      return RefreshIndicator(
        onRefresh: () => _cargar(silencioso: true),
        child: LayoutBuilder(
          builder: (context, restricciones) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: restricciones.maxHeight),
              child: Center(
                child: VistaEstado(
                  key: const Key('solicitudes-vacio'),
                  icono: Icons.receipt_long_outlined,
                  titulo: todas
                      ? 'Aún no hay solicitudes.'
                      : 'No hay solicitudes con este estado.',
                  mensaje: todas
                      ? 'Crea una y te avisaremos cuando un técnico la acepte.'
                      : null,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      child: ListView(
        key: const Key('lista-solicitudes'),
        padding: const EdgeInsets.fromLTRB(
          QpEspacio.pantalla,
          0,
          QpEspacio.pantalla,
          // Espacio para que el botón flotante no tape la última solicitud.
          QpEspacio.e12 * 2,
        ),
        children: [
          Text(
            _total == 1 ? '1 solicitud' : '$_total solicitudes',
            key: const Key('total-solicitudes'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: QpEspacio.e2),
          for (final s in _solicitudes)
            Padding(
              padding: const EdgeInsets.only(bottom: QpEspacio.e2),
              child: TarjetaSolicitud(
                key: Key('solicitud-${s.id}'),
                servicio: nombres[s.categoriaId] ?? 'Solicitud de servicio',
                descripcion: s.descripcion,
                direccion: [
                  ?s.sede,
                  if (s.clienteId != yo)
                    'Creada por otro usuario de la empresa',
                ].join(' · ').ifNotEmpty,
                estado: s.estado,
                fecha: s.creadaEn,
                alTocar: () => context.push(
                  s.clienteId == yo
                      ? Rutas.detalleSolicitud(s.id)
                      : Rutas.detalleSolicitudSoloLectura(s.id),
                ),
              ),
            ),
          if (_solicitudes.length < _total)
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

extension on String {
  /// `null` si está vacío, para no mostrar una línea en blanco.
  String? get ifNotEmpty => isEmpty ? null : this;
}
