import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/codigo_error.dart';
import '../../../../core/session/controlador_sesion.dart';
import '../../../../core/utils/validadores.dart';
import '../../../../shared/widgets/boton_principal.dart';
import '../../../../shared/widgets/mensaje_error.dart';
import '../../../solicitudes/data/repositorio_solicitudes.dart';
import '../../data/repositorio_pagos.dart';
import '../../data/tokenizador_tarjetas.dart';
import '../../domain/pago.dart';

/// Pago con tarjeta (RF-22, SCRUM-116). La tarjeta se cambia por un token en el
/// dispositivo con el tokenizador de la pasarela; a Payments solo viajan el
/// token y los datos del comprobante (ADR-009, RN-P1). El monto no se envía:
/// es el de la cotización aceptada.
///
/// Al terminar vuelve al detalle con `true` si el pago cambió (aprobado, en
/// proceso o ya pagado). Un rechazo se queda aquí para intentar de nuevo.
class PagarPage extends ConsumerStatefulWidget {
  const PagarPage({required this.solicitudId, super.key});

  final String solicitudId;

  @override
  ConsumerState<PagarPage> createState() => _PagarPageState();
}

class _PagarPageState extends ConsumerState<PagarPage> {
  final _formulario = GlobalKey<FormState>();
  final _numero = TextEditingController();
  final _vencimiento = TextEditingController();
  final _cvv = TextEditingController();
  final _nombre = TextEditingController();
  final _documento = TextEditingController();
  final _correo = TextEditingController();
  var _tipo = TipoDocumento.cc;
  var _enviando = false;
  String? _error;
  Map<String, String> _erroresCampo = const {};

  @override
  void initState() {
    super.initState();
    // El nombre del comprobante empieza con el de la sesión; el cliente lo
    // puede cambiar, por ejemplo por la razón social de su empresa.
    ref.listenManual(controladorSesionProvider, (_, sesion) {
      final nombre = sesion.value?.usuario.fullName;
      if (_nombre.text.isEmpty && nombre != null) _nombre.text = nombre;
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    for (final c in [
      _numero,
      _vencimiento,
      _cvv,
      _nombre,
      _documento,
      _correo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _usarTarjeta(String numero) {
    _numero.text = numero
        .replaceAllMapped(RegExp(r'.{4}'), (m) => '${m.group(0)} ')
        .trim();
    _vencimiento.text = '12/30';
    _cvv.text = '123';
    setState(() => _erroresCampo = const {});
  }

  Future<void> _pagar() async {
    setState(() {
      _error = null;
      _erroresCampo = const {};
    });
    if (!(_formulario.currentState?.validate() ?? false)) return;
    setState(() => _enviando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final tarjeta = await ref
          .read(tokenizadorTarjetasProvider)
          .tokenizar(
            numero: _numero.text,
            vencimiento: _vencimiento.text,
            cvv: _cvv.text,
          );
      final pago = await ref
          .read(repositorioPagosProvider)
          .pagar(
            widget.solicitudId,
            token: tarjeta.token,
            facturacion: DatosFacturacion(
              nombre: _nombre.text,
              tipoDocumento: _tipo,
              numeroDocumento: _documento.text,
              correo: _correo.text,
            ),
          );
      _refrescar();
      if (!mounted) return;
      if (pago.estado == EstadoPago.rechazado) {
        _cvv.clear();
        setState(() => _error = '${pago.motivoLegible} Revisa la tarjeta.');
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Pago aprobado con la tarjeta terminada en ${tarjeta.ultimosCuatro}.',
          ),
        ),
      );
      context.pop(true);
    } on TarjetaInvalida catch (e) {
      setState(() => _erroresCampo = {e.campo: e.mensaje});
      _formulario.currentState?.validate();
    } on AppException catch (e) {
      if (!mounted) return;
      const terminales = {
        CodigoError.paymentProviderError,
        CodigoError.paymentInProgress,
        CodigoError.alreadyPaid,
        CodigoError.paymentNotReady,
      };
      if (terminales.contains(e.codigo)) {
        _refrescar();
        messenger.showSnackBar(SnackBar(content: Text(e.mensaje)));
        context.pop(true);
        return;
      }
      setState(() {
        _erroresCampo = {
          for (final campo in e.erroresCampo)
            campo.campo.replaceFirst('billing.', ''): campo.mensaje,
        };
        _error = e.mensaje;
      });
      _formulario.currentState?.validate();
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _refrescar() {
    ref
      ..invalidate(pagoProvider(widget.solicitudId))
      ..invalidate(solicitudProvider(widget.solicitudId));
  }

  String? _requerido(String? valor, String mensaje) =>
      (valor?.trim().isEmpty ?? true) ? mensaje : null;

  @override
  Widget build(BuildContext context) {
    final pago = ref.watch(pagoProvider(widget.solicitudId)).value;
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Pagar el servicio')),
      body: SafeArea(
        child: Form(
          key: _formulario,
          child: ListView(
            padding: const EdgeInsets.all(QpEspacio.pantalla),
            children: [
              if (pago != null) ...[
                Text('Total a pagar', style: tema.textTheme.bodyMedium),
                Text(
                  pago.monto.formatear(),
                  key: const Key('total-a-pagar'),
                  style: tema.textTheme.headlineMedium,
                ),
                const SizedBox(height: QpEspacio.e4),
              ],
              _TarjetasDePrueba(alElegir: _usarTarjeta),
              const SizedBox(height: QpEspacio.e5),
              Semantics(
                header: true,
                child: Text('Tarjeta', style: tema.textTheme.titleMedium),
              ),
              const SizedBox(height: QpEspacio.e3),
              TextFormField(
                key: const Key('campo-numero'),
                controller: _numero,
                decoration: const InputDecoration(
                  labelText: 'Número de la tarjeta',
                  prefixIcon: Icon(Icons.credit_card_rounded),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
                  LengthLimitingTextInputFormatter(23),
                ],
                validator: (v) =>
                    _erroresCampo['numero'] ??
                    _requerido(v, 'Escribe el número de la tarjeta.'),
              ),
              const SizedBox(height: QpEspacio.e3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('campo-vencimiento'),
                      controller: _vencimiento,
                      decoration: const InputDecoration(
                        labelText: 'Vence (MM/AA)',
                      ),
                      keyboardType: TextInputType.datetime,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d/]')),
                        LengthLimitingTextInputFormatter(5),
                      ],
                      validator: (v) =>
                          _erroresCampo['vencimiento'] ??
                          _requerido(v, 'Escribe el vencimiento.'),
                    ),
                  ),
                  const SizedBox(width: QpEspacio.e3),
                  Expanded(
                    child: TextFormField(
                      key: const Key('campo-cvv'),
                      controller: _cvv,
                      decoration: const InputDecoration(labelText: 'CVV'),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      validator: (v) =>
                          _erroresCampo['cvv'] ??
                          _requerido(v, 'Escribe el código.'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: QpEspacio.e2),
              Text(
                'Los datos de la tarjeta no salen de tu celular: QUICKPATCH '
                'solo recibe un código de la pasarela.',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: QpEspacio.e5),
              Semantics(
                header: true,
                child: Text(
                  'Datos del comprobante',
                  style: tema.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: QpEspacio.e3),
              TextFormField(
                key: const Key('campo-nombre'),
                controller: _nombre,
                decoration: const InputDecoration(
                  labelText: 'Nombre o razón social',
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  final texto = v?.trim() ?? '';
                  if (_erroresCampo['name'] case final error?) return error;
                  return texto.length < 2 || texto.length > 150
                      ? 'Escribe entre 2 y 150 caracteres.'
                      : null;
                },
              ),
              const SizedBox(height: QpEspacio.e3),
              DropdownButtonFormField<TipoDocumento>(
                key: const Key('campo-tipo-documento'),
                initialValue: _tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de documento',
                ),
                items: [
                  for (final t in TipoDocumento.values)
                    DropdownMenuItem(value: t, child: Text(t.nombre)),
                ],
                onChanged: (t) => setState(() => _tipo = t ?? _tipo),
              ),
              const SizedBox(height: QpEspacio.e3),
              TextFormField(
                key: const Key('campo-documento'),
                controller: _documento,
                decoration: const InputDecoration(
                  labelText: 'Número de documento',
                ),
                validator: (v) {
                  if (_erroresCampo['documentNumber'] case final error?) {
                    return error;
                  }
                  return RegExp(r'^[0-9A-Za-z-]{4,20}$')
                          .hasMatch(v?.trim() ?? '')
                      ? null
                      : 'Usa entre 4 y 20 letras, números o guiones.';
                },
              ),
              const SizedBox(height: QpEspacio.e3),
              TextFormField(
                key: const Key('campo-correo'),
                controller: _correo,
                decoration: const InputDecoration(
                  labelText: 'Correo para el comprobante',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => _erroresCampo['email'] ?? validarEmail(v),
              ),
              const SizedBox(height: QpEspacio.e5),
              if (_error != null) ...[
                MensajeError(_error!, key: const Key('error-pago')),
                const SizedBox(height: QpEspacio.e3),
              ],
              BotonPrincipal(
                key: const Key('confirmar-pago'),
                texto: pago == null
                    ? 'Pagar'
                    : 'Pagar ${pago.monto.formatear()}',
                icono: Icons.lock_rounded,
                cargando: _enviando,
                alPresionar: _pagar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso del modo de pruebas con las tarjetas de la pasarela simulada; al
/// tocar una, llena el formulario.
class _TarjetasDePrueba extends StatelessWidget {
  const _TarjetasDePrueba({required this.alElegir});

  final ValueChanged<String> alElegir;

  @override
  Widget build(BuildContext context) {
    final estados = context.estados;
    const opciones = [
      (TarjetasDePrueba.aprobada, 'Aprobada'),
      (TarjetasDePrueba.rechazada, 'Rechazada por fondos'),
      (TarjetasDePrueba.sinRespuesta, 'Pasarela sin respuesta'),
    ];
    return DecoratedBox(
      key: const Key('tarjetas-de-prueba'),
      decoration: BoxDecoration(
        color: estados.infoFondo,
        borderRadius: BorderRadius.circular(QpRadio.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(QpEspacio.e3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Modo de pruebas: no se hacen cobros reales. Toca una tarjeta '
              'de prueba para usarla.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: estados.info),
            ),
            const SizedBox(height: QpEspacio.e2),
            Wrap(
              spacing: QpEspacio.e2,
              runSpacing: QpEspacio.e2,
              children: [
                for (final (numero, nombre) in opciones)
                  ActionChip(
                    key: Key('tarjeta-$numero'),
                    label: Text('$nombre · ${numero.substring(12)}'),
                    onPressed: () => alElegir(numero),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
