import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/fechas.dart';
import '../../../../core/utils/monto.dart';
import '../../data/repositorio_solicitudes.dart';
import '../../domain/modelos.dart';
import 'desglose_cotizacion.dart';

/// Cotización del técnico asignado (RF-34, SCRUM-489; service-request 1.6.0).
///
/// En `asignado` muestra el formulario con el total antes de enviar; en
/// `cotizado`, la cotización que espera respuesta; en `cotizacion_aceptada`,
/// la aceptada. Las rechazadas o vencidas quedan debajo con su motivo. El
/// backend vuelve a validar el estado y responde `409` si ya cambió.
class CotizacionTecnico extends ConsumerWidget {
  const CotizacionTecnico({
    required this.solicitud,
    required this.alCambiar,
    super.key,
  });

  final Solicitud solicitud;

  /// Vuelve a pedir la solicitud y sus cotizaciones.
  final VoidCallback alCambiar;

  /// Estados en los que el técnico ve la cotización.
  static bool aplica(EstadoSolicitud estado) =>
      estado == EstadoSolicitud.asignado ||
      estado == EstadoSolicitud.cotizado ||
      estado == EstadoSolicitud.cotizacionAceptada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!aplica(solicitud.estado)) return const SizedBox.shrink();
    return ref
        .watch(cotizacionesProvider(solicitud.id))
        .when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          loading: () => const SeccionCotizacion(
            titulo: 'Cotización',
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SeccionCotizacion(
            key: const Key('error-cotizaciones'),
            titulo: 'Cotización',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('No pudimos cargar tus cotizaciones.'),
                const SizedBox(height: QpEspacio.e2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: alCambiar,
                    child: const Text('Reintentar'),
                  ),
                ),
              ],
            ),
          ),
          data: (lista) => _Contenido(
            solicitud: solicitud,
            cotizaciones: lista,
            alCambiar: alCambiar,
          ),
        );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.solicitud,
    required this.cotizaciones,
    required this.alCambiar,
  });

  final Solicitud solicitud;
  final List<Cotizacion> cotizaciones;
  final VoidCallback alCambiar;

  @override
  Widget build(BuildContext context) {
    final vigente = cotizaciones
        .where(
          (c) =>
              c.estado == EstadoCotizacion.pendiente ||
              c.estado == EstadoCotizacion.aceptada,
        )
        .lastOrNull;
    final anteriores = cotizaciones
        .where((c) => !identical(c, vigente))
        .toList()
        .reversed;
    final restantes = LimitesCotizacion.maximo - cotizaciones.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (solicitud.estado == EstadoSolicitud.asignado)
          restantes > 0
              ? FormularioCotizacion(
                  solicitudId: solicitud.id,
                  numero: cotizaciones.length + 1,
                  alCambiar: alCambiar,
                )
              : const SeccionCotizacion(
                  key: Key('sin-cotizaciones-restantes'),
                  titulo: 'Cotización',
                  child: Text(
                    'Ya enviaste las 3 cotizaciones permitidas para esta '
                    'solicitud.',
                  ),
                )
        else if (vigente != null)
          SeccionCotizacion(
            key: const Key('cotizacion-vigente'),
            titulo: vigente.estado == EstadoCotizacion.aceptada
                ? 'El cliente aceptó tu cotización'
                : 'Esperando la respuesta del cliente',
            child: DesgloseCotizacion(vigente),
          ),
        for (final c in anteriores) ...[
          const SizedBox(height: QpEspacio.e4),
          SeccionCotizacion(
            key: Key('cotizacion-anterior-${c.numero}'),
            titulo:
                'Cotización ${c.numero}: ${c.estado.etiqueta.toLowerCase()}',
            child: DesgloseCotizacion(c),
          ),
        ],
      ],
    );
  }
}

/// Formulario de la cotización (`IssueQuote`). El técnico escribe pesos
/// enteros; la app los envía con dos decimales y muestra el total antes de
/// enviar. La mano de obra debe ser mayor que 0; los materiales pueden quedar
/// vacíos (0).
class FormularioCotizacion extends ConsumerStatefulWidget {
  const FormularioCotizacion({
    required this.solicitudId,
    required this.numero,
    required this.alCambiar,
    super.key,
  });

  final String solicitudId;

  /// Número que tendrá la cotización (1 a 3).
  final int numero;
  final VoidCallback alCambiar;

  @override
  ConsumerState<FormularioCotizacion> createState() =>
      _FormularioCotizacionState();
}

class _FormularioCotizacionState extends ConsumerState<FormularioCotizacion> {
  final _manoDeObra = TextEditingController();
  final _materiales = TextEditingController();
  final _detalle = TextEditingController();
  String? _errorManoDeObra;
  String? _errorMateriales;
  String? _errorDetalle;
  String? _errorGeneral;
  var _enviando = false;

  @override
  void initState() {
    super.initState();
    _manoDeObra.addListener(_alEscribir);
    _materiales.addListener(_alEscribir);
  }

  @override
  void dispose() {
    _manoDeObra.dispose();
    _materiales.dispose();
    _detalle.dispose();
    super.dispose();
  }

  void _alEscribir() => setState(() {});

  static int _pesos(TextEditingController campo) =>
      int.tryParse(campo.text) ?? 0;

  int get _total => _pesos(_manoDeObra) + _pesos(_materiales);

  static Monto _monto(int pesos) => Monto('$pesos.00');

  /// El total también es `Money`: como máximo 10 dígitos enteros.
  static final _totalMaximo = int.parse('9' * LimitesCotizacion.digitosMaximos);

  Future<void> _enviar() async {
    final manoDeObra = _pesos(_manoDeObra);
    setState(() {
      _errorManoDeObra = manoDeObra > 0
          ? null
          : 'Escribe el valor de la mano de obra (mayor que \$ 0).';
      _errorMateriales = _total > _totalMaximo
          ? 'El total no puede superar ${_monto(_totalMaximo).formatear()}.'
          : null;
      _errorDetalle = null;
      _errorGeneral = null;
    });
    if (_errorManoDeObra != null || _errorMateriales != null) return;

    setState(() => _enviando = true);
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final cotizacion = await ref
          .read(repositorioSolicitudesProvider)
          .cotizar(
            widget.solicitudId,
            manoDeObra: _monto(manoDeObra),
            materiales: _monto(_pesos(_materiales)),
            detalle: _detalle.text,
          );
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            'Enviaste la cotización. El cliente tiene hasta el '
            '${fechaCorta(cotizacion.venceEn.toLocal())} para responder.',
          ),
        ),
      );
      widget.alCambiar();
    } on AppException catch (e) {
      if (!mounted) return;
      if (e.status == 409) {
        mensajero.showSnackBar(
          SnackBar(
            key: const Key('aviso-conflicto-cotizacion'),
            content: Text(
              e.esProblema('limite-de-cotizaciones')
                  ? 'Ya enviaste las 3 cotizaciones permitidas para esta '
                        'solicitud.'
                  : 'La solicitud ya no admite una cotización: puede que el '
                        'cliente la haya cancelado o que ya tengas una '
                        'pendiente.',
            ),
          ),
        );
        setState(() => _enviando = false);
        widget.alCambiar();
        return;
      }
      setState(() {
        _enviando = false;
        _errorManoDeObra = e.errorDe('laborAmount');
        _errorMateriales = e.errorDe('materialsAmount');
        _errorDetalle = e.errorDe('detail');
        _errorGeneral =
            _errorManoDeObra == null &&
                _errorMateriales == null &&
                _errorDetalle == null
            ? e.mensaje
            : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final secundario = Theme.of(context).colorScheme.onSurfaceVariant;
    final restantes = LimitesCotizacion.maximo - widget.numero;
    return SeccionCotizacion(
      key: const Key('formulario-cotizacion'),
      titulo: 'Cotización ${widget.numero} de ${LimitesCotizacion.maximo}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Revisa el trabajo y envía el valor al cliente. Cuando la acepte, '
            'podrás iniciar el servicio.',
            style: texto.bodyMedium?.copyWith(color: secundario),
          ),
          const SizedBox(height: QpEspacio.e4),
          _CampoPesos(
            clave: const Key('campo-mano-de-obra'),
            controlador: _manoDeObra,
            etiqueta: 'Mano de obra',
            error: _errorManoDeObra,
            habilitado: !_enviando,
          ),
          const SizedBox(height: QpEspacio.e3),
          _CampoPesos(
            clave: const Key('campo-materiales'),
            controlador: _materiales,
            etiqueta: 'Materiales (opcional)',
            ayuda: 'Déjalo vacío si no necesitas materiales.',
            error: _errorMateriales,
            habilitado: !_enviando,
          ),
          const SizedBox(height: QpEspacio.e3),
          TextField(
            key: const Key('campo-detalle-cotizacion'),
            controller: _detalle,
            enabled: !_enviando,
            minLines: 2,
            maxLines: 5,
            maxLength: LimitesCotizacion.detalleMaximo,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Qué incluye (opcional)',
              hintText: 'Por ejemplo: cambio de sifón y empaques',
              errorText: _errorDetalle,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: QpEspacio.e2),
          Semantics(
            liveRegion: true,
            child: LineaMonto(
              'Total para el cliente',
              _total > _totalMaximo
                  ? 'Supera el máximo'
                  : _monto(_total).formatear(),
              clave: const Key('total-nueva-cotizacion'),
              destacada: true,
            ),
          ),
          if (_errorGeneral != null) ...[
            const SizedBox(height: QpEspacio.e2),
            Text(
              _errorGeneral!,
              key: const Key('error-cotizacion'),
              style: texto.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: QpEspacio.e4),
          FilledButton.icon(
            key: const Key('boton-enviar-cotizacion'),
            onPressed: _enviando ? null : _enviar,
            icon: _enviando
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(_enviando ? 'Enviando' : 'Enviar cotización'),
          ),
          const SizedBox(height: QpEspacio.e2),
          Text(
            restantes == 0
                ? 'Es tu última cotización: si el cliente la rechaza, la '
                      'solicitud se cancela.'
                : 'Si el cliente la rechaza, puedes enviar '
                      '${restantes == 1 ? 'una más' : 'hasta $restantes más'}.',
            key: const Key('cotizaciones-restantes'),
            textAlign: TextAlign.center,
            style: texto.bodySmall?.copyWith(color: secundario),
          ),
        ],
      ),
    );
  }
}

/// Valor en pesos enteros, sin puntos ni decimales.
class _CampoPesos extends StatelessWidget {
  const _CampoPesos({
    required this.clave,
    required this.controlador,
    required this.etiqueta,
    required this.habilitado,
    this.ayuda,
    this.error,
  });

  final Key clave;
  final TextEditingController controlador;
  final String etiqueta;
  final bool habilitado;
  final String? ayuda;
  final String? error;

  @override
  Widget build(BuildContext context) => TextField(
    key: clave,
    controller: controlador,
    enabled: habilitado,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(LimitesCotizacion.digitosMaximos),
    ],
    decoration: InputDecoration(
      labelText: etiqueta,
      prefixText: '\$ ',
      helperText: ayuda,
      errorText: error,
      errorMaxLines: 3,
    ),
  );
}

/// Tarjeta con título de la cotización; la usan el técnico y el cliente.
class SeccionCotizacion extends StatelessWidget {
  const SeccionCotizacion({
    required this.titulo,
    required this.child,
    super.key,
  });

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(QpEspacio.e4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(titulo, style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: QpEspacio.e3),
          child,
        ],
      ),
    ),
  );
}
