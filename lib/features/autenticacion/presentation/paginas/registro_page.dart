import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/datos_registro.dart';
import '../controlador_sesion.dart';
import 'inicio_sesion_page.dart' show validarEmail;

/// Registro de cliente hogar (RF-01) o empresa cliente (RF-06).
/// Al terminar inicia sesión y el router lleva al inicio.
class RegistroPage extends ConsumerStatefulWidget {
  const RegistroPage({super.key});

  @override
  ConsumerState<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends ConsumerState<RegistroPage> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  final _password = TextEditingController();
  final _confirmacion = TextEditingController();
  final _razonSocial = TextEditingController();
  final _nit = TextEditingController();
  TipoCuenta _tipo = TipoCuenta.hogar;
  bool _enviando = false;
  AppException? _error;

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _email,
      _telefono,
      _password,
      _confirmacion,
      _razonSocial,
      _nit,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _error = null);
    if (!_formulario.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      await ref
          .read(controladorSesionProvider.notifier)
          .registrarEIniciarSesion(
            DatosRegistro(
              tipo: _tipo,
              nombreCompleto: _nombre.text,
              email: _email.text,
              password: _password.text,
              telefono: _telefono.text,
              razonSocial: _razonSocial.text,
              nit: _nit.text,
            ),
          );
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Muestra junto al campo el error que devolvió el backend para ese campo.
  InputDecoration _decoracion(String etiqueta, String campo) =>
      InputDecoration(labelText: etiqueta, errorText: _error?.errorDe(campo));

  @override
  Widget build(BuildContext context) {
    final esEmpresa = _tipo == TipoCuenta.empresa;
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formulario,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (AppConfig.registroEmpresaHabilitado)
                  SegmentedButton<TipoCuenta>(
                    key: const Key('selector-tipo'),
                    segments: const [
                      ButtonSegment(
                        value: TipoCuenta.hogar,
                        label: Text('Hogar'),
                        icon: Icon(Icons.home_outlined),
                      ),
                      ButtonSegment(
                        value: TipoCuenta.empresa,
                        label: Text('Empresa'),
                        icon: Icon(Icons.business_outlined),
                      ),
                    ],
                    selected: {_tipo},
                    onSelectionChanged: (s) => setState(() => _tipo = s.first),
                  ),
                const SizedBox(height: 24),
                if (esEmpresa) ...[
                  TextFormField(
                    key: const Key('campo-razon-social'),
                    controller: _razonSocial,
                    textInputAction: TextInputAction.next,
                    decoration: _decoracion('Razón social', 'legalName'),
                    validator: (v) => _obligatorio(v, 150),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('campo-nit'),
                    controller: _nit,
                    textInputAction: TextInputAction.next,
                    decoration: _decoracion('NIT', 'nit'),
                    validator: (v) => _obligatorio(v, 30),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  key: const Key('campo-nombre'),
                  controller: _nombre,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: _decoracion(
                    esEmpresa ? 'Nombre de quien solicita' : 'Nombre completo',
                    'fullName',
                  ),
                  validator: (v) => _obligatorio(v, 150),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('campo-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: _decoracion('Correo electrónico', 'email'),
                  validator: validarEmail,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('campo-telefono'),
                  controller: _telefono,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: _decoracion('Teléfono (opcional)', 'phone'),
                  validator: (v) => (v ?? '').trim().length > 30
                      ? 'Máximo 30 caracteres.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('campo-password'),
                  controller: _password,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: _decoracion('Contraseña', 'password'),
                  validator: validarContrasena,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('campo-confirmacion'),
                  controller: _confirmacion,
                  obscureText: true,
                  onFieldSubmitted: (_) => _enviar(),
                  decoration: const InputDecoration(
                    labelText: 'Confirma la contraseña',
                  ),
                  validator: (v) => v == _password.text
                      ? null
                      : 'Las contraseñas no coinciden.',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!.mensaje,
                    key: const Key('mensaje-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('boton-registrar'),
                  onPressed: _enviando ? null : _enviar,
                  child: _enviando
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Crear cuenta'),
                ),
                TextButton(
                  onPressed: () => context.go(Rutas.iniciarSesion),
                  child: const Text('Ya tengo cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _obligatorio(String? valor, int maximo) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return 'Es obligatorio.';
  if (texto.length > maximo) return 'Máximo $maximo caracteres.';
  return null;
}

/// Mismos límites que el contrato: entre 8 y 128 caracteres.
String? validarContrasena(String? valor) {
  final texto = valor ?? '';
  if (texto.length < 8) return 'Usa al menos 8 caracteres.';
  if (texto.length > 128) return 'Máximo 128 caracteres.';
  return null;
}
