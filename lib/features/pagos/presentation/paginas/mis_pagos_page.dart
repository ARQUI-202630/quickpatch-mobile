import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/session/controlador_sesion.dart';
import '../../../../core/session/rol_usuario.dart';
import '../../../../core/utils/fechas.dart';
import '../../../../shared/widgets/vista_error.dart';
import '../../../../shared/widgets/vista_estado.dart';
import '../../../equipo/data/repositorio_equipo.dart';
import '../../../equipo/domain/modelos.dart';
import '../../data/repositorio_pagos.dart';
import '../../domain/pago.dart';
import '../../domain/pago_recibido.dart';

/// Pagos recibidos, desde Cuenta (SCRUM-502), con `GET /v1/payments/received`
/// (payments 1.2.0, RF-25). El técnico ve los suyos; el proveedor, los de su
/// equipo, y puede ver los de un solo técnico. El pago solo trae el
/// identificador del técnico: el proveedor ve su nombre gracias a la lista
/// del equipo. No hay detalle del pago en el contrato.
class MisPagosPage extends ConsumerStatefulWidget {
  const MisPagosPage({super.key});

  @override
  ConsumerState<MisPagosPage> createState() => _MisPagosPageState();
}

class _MisPagosPageState extends ConsumerState<MisPagosPage> {
  FiltroPagosRecibidos _filtro = FiltroPagosRecibidos.todos;

  /// Técnico elegido por el proveedor; `null` es todo el equipo.
  String? _tecnicoId;
  List<PagoRecibido> _pagos = const [];
  int _pagina = 0;
  int _total = 0;
  bool _cargando = true;
  bool _cargandoMas = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  RepositorioPagos get _repositorio => ref.read(repositorioPagosProvider);

  bool get _esProveedor =>
      ref.read(controladorSesionProvider).value?.usuario.rol ==
      RolUsuario.proveedor;

  /// Consulta vigente; una respuesta de otra consulta se descarta.
  (FiltroPagosRecibidos, String?) get _consulta => (_filtro, _tecnicoId);

  /// Carga la primera página de la consulta actual. [silencioso] la recarga
  /// sin quitar la lista que se ve.
  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    final consulta = _consulta;
    try {
      final pagina = await _repositorio.recibidos(
        estado: _filtro.estado,
        tecnicoId: _tecnicoId,
      );
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _pagos = pagina.pagos;
        _pagina = pagina.pagina;
        _total = pagina.total;
        _error = null;
      });
    } on AppException catch (e) {
      if (!mounted || consulta != _consulta) return;
      // Al recargar en silencio, un fallo no borra lo que ya se ve.
      if (silencioso && _pagos.isNotEmpty) {
        _avisar(e.mensaje);
      } else {
        setState(() => _error = e);
      }
    } finally {
      if (mounted && consulta == _consulta) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarMas() async {
    setState(() => _cargandoMas = true);
    final consulta = _consulta;
    try {
      final pagina = await _repositorio.recibidos(
        estado: _filtro.estado,
        tecnicoId: _tecnicoId,
        pagina: _pagina + 1,
      );
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _pagos = [..._pagos, ...pagina.pagos];
        _pagina = pagina.pagina;
        _total = pagina.total;
      });
    } on AppException catch (e) {
      _avisar(e.mensaje);
    } finally {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  void _filtrar(FiltroPagosRecibidos filtro) {
    if (filtro == _filtro) return;
    setState(() => _filtro = filtro);
    _cargar();
  }

  void _elegirTecnico(String? tecnicoId) {
    if (tecnicoId == _tecnicoId) return;
    setState(() => _tecnicoId = tecnicoId);
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
    // Sin la lista del equipo, los pagos se muestran igual, sin el nombre.
    final equipo = _esProveedor
        ? ref.watch(equipoCompletoProvider).value
        : null;
    final nombres = {
      for (final t in equipo ?? const <TecnicoEquipo>[]) t.userId: t.nombre,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Mis pagos')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (equipo != null && equipo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  QpEspacio.pantalla,
                  QpEspacio.e2,
                  QpEspacio.pantalla,
                  0,
                ),
                child: DropdownButtonFormField<String?>(
                  key: const Key('selector-tecnico'),
                  initialValue: _tecnicoId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Técnico'),
                  items: [
                    const DropdownMenuItem(child: Text('Todo el equipo')),
                    for (final t in equipo)
                      DropdownMenuItem(
                        value: t.userId,
                        child: Text(t.nombre, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: _elegirTecnico,
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
                key: const Key('filtro-pagos'),
                spacing: QpEspacio.e2,
                runSpacing: QpEspacio.e2,
                children: [
                  for (final f in FiltroPagosRecibidos.values)
                    ChoiceChip(
                      key: Key('filtro-${f.name}'),
                      label: Text(f.etiqueta),
                      selected: f == _filtro,
                      onSelected: (_) => _filtrar(f),
                    ),
                ],
              ),
            ),
            Expanded(child: _contenido(_esProveedor ? nombres : null)),
          ],
        ),
      ),
    );
  }

  /// [nombres] del equipo por técnico; `null` para el técnico, que no los
  /// necesita.
  Widget _contenido(Map<String, String>? nombres) {
    if (_cargando) {
      return const IndicadorCarga(etiqueta: 'Cargando tus pagos');
    }
    if (_error case final error?) {
      return Center(
        child: SingleChildScrollView(
          child: VistaError(
            key: const Key('error-pagos'),
            error: error,
            titulo: 'No pudimos cargar tus pagos.',
            alReintentar: _cargar,
          ),
        ),
      );
    }
    if (_pagos.isEmpty) {
      final todos = _filtro == FiltroPagosRecibidos.todos;
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
                  key: const Key('pagos-vacio'),
                  icono: Icons.payments_outlined,
                  titulo: todos
                      ? 'Aún no hay pagos.'
                      : 'No hay pagos ${_filtro.etiqueta.toLowerCase()}.',
                  mensaje: _filtro.mensajeVacio,
                ),
              ),
            ),
          ),
        ),
      );
    }
    final hayMas = _pagos.length < _total;
    return RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      child: ListView(
        key: const Key('lista-pagos'),
        padding: const EdgeInsets.fromLTRB(
          QpEspacio.pantalla,
          0,
          QpEspacio.pantalla,
          QpEspacio.e8,
        ),
        children: [
          Text(
            _total == 1 ? '1 pago' : '$_total pagos',
            key: const Key('total-pagos'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: QpEspacio.e2),
          for (final p in _pagos)
            Padding(
              padding: const EdgeInsets.only(bottom: QpEspacio.e2),
              child: TarjetaPagoRecibido(
                key: Key('pago-${p.id}'),
                pago: p,
                tecnico: nombres == null
                    ? null
                    : nombres[p.tecnicoId] ?? 'Técnico del equipo',
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

/// Un pago recibido: monto, estado, fecha y, para el proveedor, [tecnico].
class TarjetaPagoRecibido extends StatelessWidget {
  const TarjetaPagoRecibido({required this.pago, this.tecnico, super.key});

  final PagoRecibido pago;
  final String? tecnico;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final secundario = texto.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final fecha = switch (pago.aprobadoEn) {
      final aprobado? => 'Recibido el ${fechaCorta(aprobado.toLocal())}',
      null => 'Servicio completado el ${fechaCorta(pago.creadoEn.toLocal())}',
    };
    return Card(
      child: MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(QpEspacio.e4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: QpEspacio.e3,
                runSpacing: QpEspacio.e2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(pago.monto.formatear(), style: texto.titleMedium),
                  _EstadoPagoRecibido(pago.estado),
                ],
              ),
              if (tecnico case final nombre?) ...[
                const SizedBox(height: QpEspacio.e1),
                Text(nombre, style: texto.bodyMedium),
              ],
              const SizedBox(height: QpEspacio.e1),
              Text(fecha, style: secundario),
            ],
          ),
        ),
      ),
    );
  }
}

/// Insignia del estado del pago, en el tono del estado (texto 700 sobre
/// fondo 50, como `ChipEstado`).
class _EstadoPagoRecibido extends StatelessWidget {
  const _EstadoPagoRecibido(this.estado);

  final EstadoPago estado;

  @override
  Widget build(BuildContext context) {
    final estados = context.estados;
    final (etiqueta, icono, color, fondo) = switch (estado) {
      EstadoPago.aprobado => (
        'Recibido',
        Icons.check_circle_rounded,
        estados.exito,
        estados.exitoFondo,
      ),
      EstadoPago.procesando => (
        'Procesando',
        Icons.hourglass_top_rounded,
        estados.info,
        estados.infoFondo,
      ),
      // `rechazado` no llega en esta lista (RN-P4).
      EstadoPago.pendiente || EstadoPago.rechazado => (
        'Pendiente',
        Icons.schedule_rounded,
        estados.aviso,
        estados.avisoFondo,
      ),
    };
    return Semantics(
      label: 'Estado: $etiqueta',
      excludeSemantics: true,
      child: DecoratedBox(
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
              Flexible(
                child: Text(
                  etiqueta,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
