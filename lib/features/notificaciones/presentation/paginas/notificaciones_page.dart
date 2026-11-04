import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/notificaciones/contador_notificaciones.dart';
import '../../../../core/realtime/canal_tiempo_real.dart';
import '../../../../core/realtime/mensaje_tiempo_real.dart';
import '../../../../core/session/controlador_sesion.dart';
import '../../../../core/session/rol_usuario.dart';
import '../../../../core/utils/fechas.dart';
import '../../../../shared/widgets/vista_error.dart';
import '../../../../shared/widgets/vista_estado.dart';
import '../../data/repositorio_notificaciones.dart';
import '../../domain/notificacion.dart';

/// Pantalla a la que lleva una notificación al tocarla para el [rol] de la
/// sesión, o `null` si no tiene (por ejemplo, un tipo que la app todavía no
/// conoce). `solicitud-cancelada` llega al cliente y al técnico: el técnico
/// no navega, porque fuera de asignado a completado ya no ve la solicitud
/// (RN-SR13), igual que en su aviso en vivo (SCRUM-477).
String? destinoDe(Notificacion n, RolUsuario? rol) {
  final solicitud = n.serviceRequestId;
  return switch (n.tipo) {
    'solicitud-cancelada' when rol == RolUsuario.tecnico => null,
    'solicitud-creada' ||
    'tecnico-asignado' ||
    'sin-tecnico-disponible' ||
    'busqueda-reanudada' ||
    'solicitud-cancelada' ||
    'cotizacion-recibida' when solicitud != null => Rutas.detalleSolicitud(
      solicitud,
    ),
    'solicitud-asignada' || 'cotizacion-aceptada' || 'cotizacion-rechazada'
        when solicitud != null =>
      Rutas.solicitudAsignada(solicitud),
    'oferta-recibida' => Rutas.actividad,
    'registro-recibido' || 'verificacion-actualizada' => Rutas.inicio,
    _ => null,
  };
}

IconData _iconoDe(String tipo) => switch (tipo) {
  'solicitud-creada' => Icons.receipt_long_outlined,
  'tecnico-asignado' || 'solicitud-asignada' => Icons.engineering_outlined,
  'sin-tecnico-disponible' => Icons.hourglass_empty_rounded,
  'busqueda-reanudada' => Icons.search_rounded,
  'solicitud-cancelada' => Icons.cancel_outlined,
  'cotizacion-recibida' ||
  'cotizacion-aceptada' ||
  'cotizacion-rechazada' => Icons.request_quote_outlined,
  'oferta-recibida' => Icons.work_outline_rounded,
  'registro-recibido' ||
  'verificacion-actualizada' => Icons.verified_user_outlined,
  _ => Icons.notifications_none_rounded,
};

/// Buzón de notificaciones del usuario (RIE-03, ADR-024, SCRUM-459), con
/// `GET /v1/notifications` y `POST /v1/notifications/{id}/read`
/// (communication.v1.yaml 1.2.0). Se recarga con cada aviso del canal en
/// tiempo real y, si el canal no está conectado, cada 30 s.
class NotificacionesPage extends ConsumerStatefulWidget {
  const NotificacionesPage({super.key});

  @override
  ConsumerState<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends ConsumerState<NotificacionesPage> {
  List<Notificacion> _notificaciones = const [];
  int _pagina = 0;
  int _total = 0;
  bool _cargando = true;
  bool _cargandoMas = false;

  /// Comprobando que la solicitud de la notificación tocada sigue disponible.
  bool _abriendo = false;
  Object? _error;
  CanalTiempoReal? _canal;
  StreamSubscription<MensajeTiempoReal>? _avisos;
  Timer? _respaldo;

  @override
  void initState() {
    super.initState();
    _cargar();
    _respaldo = Timer.periodic(MensajeTiempoReal.intervaloRespaldo, (_) {
      if (_canal?.estado.value != EstadoCanal.conectado) {
        _cargar(silencioso: true);
      }
    });
  }

  @override
  void dispose() {
    _respaldo?.cancel();
    unawaited(_avisos?.cancel());
    super.dispose();
  }

  RepositorioNotificaciones get _repositorio =>
      ref.read(repositorioNotificacionesProvider);

  /// Se suscribe al canal actual; cambia si la sesión crea uno nuevo.
  void _escuchar(CanalTiempoReal canal) {
    if (identical(canal, _canal)) return;
    unawaited(_avisos?.cancel());
    _canal = canal;
    _avisos = canal.avisos.listen((_) => _cargar(silencioso: true));
  }

  /// Carga la primera página. [silencioso] recarga sin quitar lo que se ve.
  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final pagina = await _repositorio.listar();
      if (!mounted) return;
      setState(() {
        _notificaciones = pagina.notificaciones;
        _pagina = pagina.pagina;
        _total = pagina.total;
        _error = null;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      // Al recargar en silencio, un fallo no borra lo que ya se ve.
      if (silencioso && _notificaciones.isNotEmpty) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarMas() async {
    setState(() => _cargandoMas = true);
    try {
      final pagina = await _repositorio.listar(pagina: _pagina + 1);
      if (!mounted) return;
      setState(() {
        _notificaciones = [..._notificaciones, ...pagina.notificaciones];
        _pagina = pagina.pagina;
        _total = pagina.total;
      });
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    } finally {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  /// La marca leída (sin esperar al servidor) y abre su pantalla. Si el
  /// marcado falla, la siguiente recarga lo corrige. Antes de abrir una
  /// solicitud comprueba que el usuario todavía la ve: un aviso viejo puede
  /// apuntar a una que ya pasó a pagado o cancelado.
  Future<void> _abrir(Notificacion n) async {
    if (_abriendo) return;
    if (!n.leida) {
      setState(() {
        _notificaciones = [
          for (final x in _notificaciones)
            x.id == n.id ? x.marcadaLeida(DateTime.now()) : x,
        ];
      });
      unawaited(_marcarLeida(n.id));
    }
    final rol = ref.read(controladorSesionProvider).value?.usuario.rol;
    final destino = destinoDe(n, rol);
    if (destino == null) return;
    // Inicio y Servicios son pestañas: se cambia de pestaña.
    if (destino == Rutas.inicio || destino == Rutas.actividad) {
      context.go(destino);
      return;
    }
    if (n.serviceRequestId case final id?) {
      if (!await _solicitudDisponible(id) || !mounted) return;
    }
    if (mounted) unawaited(context.push(destino));
  }

  /// `false` si la solicitud ya no está disponible (403 o 404), con el aviso
  /// en un SnackBar. Con otro error se navega igual: el detalle lo muestra.
  Future<bool> _solicitudDisponible(String id) async {
    setState(() => _abriendo = true);
    try {
      if (await _repositorio.solicitudDisponible(id)) return true;
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Esta solicitud ya no está disponible.'),
            ),
          );
      }
      return false;
    } on AppException {
      return true;
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  Future<void> _marcarLeida(String id) async {
    try {
      await _repositorio.marcarLeida(id);
    } on AppException {
      // La siguiente recarga muestra el estado real.
    }
    ref.invalidate(contadorNotificacionesProvider);
  }

  @override
  Widget build(BuildContext context) {
    _escuchar(ref.watch(canalTiempoRealProvider));
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: SafeArea(
        child: Column(
          children: [
            if (_abriendo)
              const LinearProgressIndicator(
                key: Key('abriendo-notificacion'),
                semanticsLabel: 'Abriendo la notificación',
              ),
            Expanded(child: _contenido()),
          ],
        ),
      ),
    );
  }

  Widget _contenido() {
    if (_cargando) {
      return const IndicadorCarga(etiqueta: 'Cargando tus notificaciones');
    }
    if (_error case final error?) {
      return Center(
        child: SingleChildScrollView(
          child: VistaError(
            key: const Key('error-notificaciones'),
            error: error,
            titulo: 'No pudimos cargar tus notificaciones.',
            alReintentar: _cargar,
          ),
        ),
      );
    }
    if (_notificaciones.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _cargar(silencioso: true),
        child: LayoutBuilder(
          builder: (context, restricciones) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: restricciones.maxHeight),
              child: const Center(
                child: VistaEstado(
                  key: Key('notificaciones-vacio'),
                  icono: Icons.notifications_none_rounded,
                  titulo: 'No tienes notificaciones.',
                  mensaje:
                      'Aquí verás lo que pase con tus solicitudes y tu '
                      'cuenta.',
                ),
              ),
            ),
          ),
        ),
      );
    }
    final hayMas = _notificaciones.length < _total;
    return RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      child: ListView(
        key: const Key('lista-notificaciones'),
        padding: const EdgeInsets.fromLTRB(
          QpEspacio.pantalla,
          QpEspacio.e2,
          QpEspacio.pantalla,
          QpEspacio.e8,
        ),
        children: [
          for (final n in _notificaciones)
            _FilaNotificacion(
              key: Key('notificacion-${n.id}'),
              notificacion: n,
              alTocar: () => unawaited(_abrir(n)),
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

class _FilaNotificacion extends StatelessWidget {
  const _FilaNotificacion({
    super.key,
    required this.notificacion,
    required this.alTocar,
  });

  final Notificacion notificacion;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final n = notificacion;
    final esquema = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    final secundario = texto.bodySmall?.copyWith(
      color: esquema.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: QpEspacio.e2),
      child: Semantics(
        // El punto de «no leída» es visual: el lector lo dice en palabras.
        label: n.leida ? null : 'No leída',
        child: Card(
          clipBehavior: Clip.antiAlias,
          color: n.leida ? null : esquema.primaryContainer,
          child: InkWell(
            onTap: alTocar,
            child: Padding(
              padding: const EdgeInsets.all(QpEspacio.e3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_iconoDe(n.tipo), color: esquema.primary),
                  const SizedBox(width: QpEspacio.e3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.titulo,
                          style: texto.titleSmall?.copyWith(
                            fontWeight: n.leida
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: QpEspacio.e1),
                        Text(
                          n.mensaje,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: QpEspacio.e1),
                        Text(
                          fechaRelativa(n.creadaEn.toLocal(), DateTime.now()),
                          style: secundario,
                        ),
                      ],
                    ),
                  ),
                  if (!n.leida) ...[
                    const SizedBox(width: QpEspacio.e2),
                    ExcludeSemantics(
                      child: Container(
                        key: const Key('punto-no-leida'),
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: QpEspacio.e1),
                        decoration: BoxDecoration(
                          color: esquema.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
