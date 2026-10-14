import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../shared/widgets/vista_error.dart';
import '../../../../shared/widgets/vista_estado.dart';
import '../../../solicitudes/data/repositorio_solicitudes.dart';
import '../../data/repositorio_equipo.dart';
import '../../domain/modelos.dart';
import '../widgets/hoja_invitacion.dart';

/// Equipo del proveedor (RF-16, SCRUM-36 / SCRUM-98): sus técnicos, filtrables
/// por activo (aprobado) o inactivo, con su especialidad y su verificación.
/// Desde aquí da de alta técnicos y genera un enlace nuevo de invitación
/// cuando el técnico perdió el suyo o se venció.
class EquipoPage extends ConsumerStatefulWidget {
  const EquipoPage({super.key});

  @override
  ConsumerState<EquipoPage> createState() => _EquipoPageState();
}

class _EquipoPageState extends ConsumerState<EquipoPage> {
  FiltroEquipo _filtro = FiltroEquipo.todos;
  List<TecnicoEquipo> _tecnicos = const [];
  int _pagina = 0;
  int _total = 0;
  bool _cargando = true;
  bool _cargandoMas = false;
  Object? _error;
  String? _generando;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  RepositorioEquipo get _repositorio => ref.read(repositorioEquipoProvider);

  /// Carga la primera página del filtro actual.
  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    final filtro = _filtro;
    try {
      final pagina = await _repositorio.listar(filtro);
      if (!mounted || filtro != _filtro) return;
      setState(() {
        _tecnicos = pagina.tecnicos;
        _pagina = pagina.pagina;
        _total = pagina.total;
      });
    } on AppException catch (e) {
      if (mounted && filtro == _filtro) setState(() => _error = e);
    } finally {
      if (mounted && filtro == _filtro) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarMas() async {
    setState(() => _cargandoMas = true);
    final filtro = _filtro;
    try {
      final pagina = await _repositorio.listar(filtro, pagina: _pagina + 1);
      if (!mounted || filtro != _filtro) return;
      setState(() {
        _tecnicos = [..._tecnicos, ...pagina.tecnicos];
        _pagina = pagina.pagina;
        _total = pagina.total;
      });
    } on AppException catch (e) {
      _avisar(e.mensaje);
    } finally {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  bool get _equipoVacio =>
      !_cargando &&
      _error == null &&
      _tecnicos.isEmpty &&
      _filtro == FiltroEquipo.todos;

  void _filtrar(FiltroEquipo filtro) {
    if (filtro == _filtro) return;
    setState(() => _filtro = filtro);
    _cargar();
  }

  Future<void> _agregar() async {
    final agregado = await context.push<bool>(Rutas.altaTecnico);
    if (agregado == true && mounted) await _cargar();
  }

  Future<void> _nuevoEnlace(TecnicoEquipo tecnico) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('¿Generar un enlace nuevo para ${tecnico.nombre}?'),
        content: const Text(
          'El enlace anterior dejará de funcionar. Úsalo si se perdió o se '
          'venció.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirmar-enlace-nuevo'),
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Generar enlace'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() => _generando = tecnico.userId);
    try {
      final invitacion = await _repositorio.nuevaInvitacion(tecnico.userId);
      if (!mounted) return;
      setState(() => _generando = null);
      await mostrarInvitacion(
        context,
        nombre: tecnico.nombre,
        invitacion: invitacion,
        esNueva: true,
      );
    } on AppException catch (e) {
      if (e.esProblema('contrasena-definida')) {
        _avisar(
          '${tecnico.nombre} ya activó su cuenta: entra con su correo y su '
          'contraseña.',
        );
      } else if (e.esProblema('no-encontrado')) {
        _avisar('${tecnico.nombre} ya no está en tu equipo.');
        await _cargar();
      } else {
        _avisar(e.mensaje);
      }
    } finally {
      if (mounted) setState(() => _generando = null);
    }
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    // Nombres de especialidad; sin catálogo la lista se muestra igual.
    final categorias = ref.watch(categoriasProvider).value ?? const [];
    final especialidades = {for (final c in categorias) c.id: c.nombre};
    return Scaffold(
      appBar: AppBar(title: const Text('Equipo')),
      // Con el equipo vacío, el estado vacío ya ofrece «Agregar técnico».
      floatingActionButton: _equipoVacio
          ? null
          : FloatingActionButton.extended(
              key: const Key('boton-agregar-tecnico'),
              onPressed: _agregar,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Agregar técnico'),
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
              child: SegmentedButton<FiltroEquipo>(
                key: const Key('filtro-equipo'),
                segments: [
                  for (final f in FiltroEquipo.values)
                    ButtonSegment(value: f, label: Text(f.etiqueta)),
                ],
                selected: {_filtro},
                showSelectedIcon: false,
                onSelectionChanged: (s) => _filtrar(s.first),
              ),
            ),
            Expanded(child: _contenido(especialidades)),
          ],
        ),
      ),
    );
  }

  Widget _contenido(Map<String, String> especialidades) {
    if (_cargando) {
      return const IndicadorCarga(etiqueta: 'Cargando tu equipo');
    }
    if (_error case final error?) {
      return Center(
        child: SingleChildScrollView(
          child: VistaError(
            key: const Key('error-equipo'),
            error: error,
            titulo: 'No pudimos cargar tu equipo.',
            alReintentar: _cargar,
          ),
        ),
      );
    }
    if (_tecnicos.isEmpty) {
      final todos = _filtro == FiltroEquipo.todos;
      return Center(
        child: SingleChildScrollView(
          child: VistaEstado(
            key: const Key('equipo-vacio'),
            icono: Icons.groups_outlined,
            titulo: todos
                ? 'Todavía no tienes técnicos en tu equipo.'
                : 'No hay técnicos ${_filtro.etiqueta.toLowerCase()}.',
            mensaje: todos
                ? 'Agrégalos y compárteles su invitación para que definan '
                      'su contraseña.'
                : null,
            accion: todos ? 'Agregar técnico' : null,
            alAccionar: todos ? _agregar : null,
          ),
        ),
      );
    }
    final hayMas = _tecnicos.length < _total;
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        key: const Key('lista-equipo'),
        padding: const EdgeInsets.fromLTRB(
          QpEspacio.pantalla,
          0,
          QpEspacio.pantalla,
          // Espacio para que el botón flotante no tape el último técnico.
          QpEspacio.e12 * 2,
        ),
        children: [
          Text(
            _total == 1 ? '1 técnico' : '$_total técnicos',
            key: const Key('total-equipo'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: QpEspacio.e2),
          for (final t in _tecnicos)
            _TarjetaTecnico(
              tecnico: t,
              especialidad: especialidades[t.especialidadId] ?? '—',
              generando: _generando == t.userId,
              alGenerarEnlace: _generando == null
                  ? () => _nuevoEnlace(t)
                  : null,
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

class _TarjetaTecnico extends StatelessWidget {
  const _TarjetaTecnico({
    required this.tecnico,
    required this.especialidad,
    required this.generando,
    required this.alGenerarEnlace,
  });

  final TecnicoEquipo tecnico;
  final String especialidad;
  final bool generando;
  final VoidCallback? alGenerarEnlace;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('tecnico-${tecnico.userId}'),
    margin: const EdgeInsets.only(bottom: QpEspacio.e2),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        QpEspacio.e4,
        QpEspacio.e3,
        QpEspacio.e1,
        QpEspacio.e3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tecnico.nombre,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: QpEspacio.e1),
                Text(
                  especialidad,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: QpEspacio.e2),
                _ChipVerificacion(tecnico.verificacion),
              ],
            ),
          ),
          if (generando)
            const Padding(
              padding: EdgeInsets.all(QpEspacio.e3),
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<String>(
              key: Key('menu-${tecnico.userId}'),
              tooltip: 'Opciones de ${tecnico.nombre}',
              enabled: alGenerarEnlace != null,
              onSelected: (_) => alGenerarEnlace?.call(),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  key: Key('opcion-enlace-nuevo'),
                  value: 'enlace',
                  child: ListTile(
                    leading: Icon(Icons.link_rounded),
                    title: Text('Generar enlace nuevo'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

/// Insignia con la verificación del técnico, en el tono del estado (texto
/// 700 sobre fondo 50, como el chip de estado de las solicitudes).
class _ChipVerificacion extends StatelessWidget {
  const _ChipVerificacion(this.estado);

  final EstadoVerificacion estado;

  @override
  Widget build(BuildContext context) {
    final estados = context.estados;
    final (icono, color, fondo) = switch (estado) {
      EstadoVerificacion.pendiente => (
        Icons.hourglass_empty_rounded,
        estados.aviso,
        estados.avisoFondo,
      ),
      EstadoVerificacion.aprobado => (
        Icons.verified_rounded,
        estados.exito,
        estados.exitoFondo,
      ),
      EstadoVerificacion.rechazado => (
        Icons.block_rounded,
        estados.peligro,
        estados.peligroFondo,
      ),
      EstadoVerificacion.suspendido => (
        Icons.pause_circle_outline_rounded,
        estados.peligro,
        estados.peligroFondo,
      ),
    };
    return Semantics(
      label: 'Verificación: ${estado.etiqueta}',
      excludeSemantics: true,
      child: DecoratedBox(
        key: Key('verificacion-${estado.valor}'),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(QpRadio.pildora),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: QpEspacio.e3,
            vertical: QpEspacio.e1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 16, color: color),
              const SizedBox(width: QpEspacio.e1),
              Text(
                estado.etiqueta,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
