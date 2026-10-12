import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../shared/widgets/boton_principal.dart';
import '../../../../shared/widgets/campo_contrasena.dart';
import '../../../../shared/widgets/mensaje_error.dart';
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
  InputDecoration _decoracion(String etiqueta, String campo, IconData icono) =>
      InputDecoration(
        labelText: etiqueta,
        errorText: _error?.errorDe(campo),
        prefixIcon: Icon(icono),
      );

  @override
  Widget build(BuildContext context) {
    final esEmpresa = _tipo == TipoCuenta.empresa;
    final texto = Theme.of(context).textTheme;
    final secundario = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            QpEspacio.pantalla,
            QpEspacio.e2,
            QpEspacio.pantalla,
            QpEspacio.e8,
          ),
          child: AutofillGroup(
            child: Form(
              key: _formulario,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Con tu cuenta pides técnicos verificados y sigues el estado '
                    'de cada servicio.',
                    style: texto.bodyMedium?.copyWith(color: secundario),
                  ),
                  const SizedBox(height: QpEspacio.e5),
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
                      onSelectionChanged: (s) =>
                          setState(() => _tipo = s.first),
                    ),
                  if (AppConfig.registroEmpresaHabilitado)
                    const SizedBox(height: QpEspacio.e5),
                  const _Seccion('Tus datos'),
                  if (esEmpresa) ...[
                    TextFormField(
                      key: const Key('campo-razon-social'),
                      controller: _razonSocial,
                      textInputAction: TextInputAction.next,
                      decoration: _decoracion(
                        'Razón social',
                        'legalName',
                        Icons.business_outlined,
                      ),
                      validator: (v) => _obligatorio(v, 150),
                    ),
                    const SizedBox(height: QpEspacio.e4),
                    TextFormField(
                      key: const Key('campo-nit'),
                      controller: _nit,
                      textInputAction: TextInputAction.next,
                      decoration: _decoracion(
                        'NIT',
                        'nit',
                        Icons.badge_outlined,
                      ),
                      validator: (v) => _obligatorio(v, 30),
                    ),
                    const SizedBox(height: QpEspacio.e4),
                  ],
                  TextFormField(
                    key: const Key('campo-nombre'),
                    controller: _nombre,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: _decoracion(
                      esEmpresa
                          ? 'Nombre de quien solicita'
                          : 'Nombre completo',
                      'fullName',
                      Icons.person_outline_rounded,
                    ),
                    validator: (v) => _obligatorio(v, 150),
                  ),
                  const SizedBox(height: QpEspacio.e4),
                  TextFormField(
                    key: const Key('campo-email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: _decoracion(
                      'Correo electrónico',
                      'email',
                      Icons.mail_outline_rounded,
                    ),
                    validator: validarEmail,
                  ),
                  const SizedBox(height: QpEspacio.e4),
                  TextFormField(
                    key: const Key('campo-telefono'),
                    controller: _telefono,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: _decoracion(
                      'Teléfono (opcional)',
                      'phone',
                      Icons.phone_outlined,
                    ),
                    validator: (v) => (v ?? '').trim().length > 30
                        ? 'Máximo 30 caracteres.'
                        : null,
                  ),
                  const SizedBox(height: QpEspacio.e6),
                  const _Seccion('Seguridad'),
                  CampoContrasena(
                    key: const Key('campo-password'),
                    controlador: _password,
                    etiqueta: 'Contraseña',
                    accionTeclado: TextInputAction.next,
                    pistasAutocompletado: const [AutofillHints.newPassword],
                    textoError: _error?.errorDe('password'),
                    validador: validarContrasena,
                  ),
                  const SizedBox(height: QpEspacio.e1),
                  Padding(
                    padding: const EdgeInsets.only(left: QpEspacio.e4),
                    child: Text(
                      'Al menos 8 caracteres.',
                      style: texto.bodySmall?.copyWith(color: secundario),
                    ),
                  ),
                  const SizedBox(height: QpEspacio.e4),
                  CampoContrasena(
                    key: const Key('campo-confirmacion'),
                    controlador: _confirmacion,
                    etiqueta: 'Confirma la contraseña',
                    pistasAutocompletado: const [AutofillHints.newPassword],
                    alEnviar: (_) => _enviar(),
                    validador: (v) => v == _password.text
                        ? null
                        : 'Las contraseñas no coinciden.',
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: QpEspacio.e4),
                    MensajeError(
                      _error!.mensaje,
                      key: const Key('mensaje-error'),
                    ),
                  ],
                  const SizedBox(height: QpEspacio.e6),
                  BotonPrincipal(
                    key: const Key('boton-registrar'),
                    texto: 'Crear cuenta',
                    cargando: _enviando,
                    alPresionar: _enviar,
                  ),
                  const SizedBox(height: QpEspacio.e2),
                  TextButton(
                    onPressed: () => context.go(Rutas.iniciarSesion),
                    child: const Text('Ya tengo cuenta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: QpEspacio.e3),
    child: Semantics(
      header: true,
      child: Text(titulo, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
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
