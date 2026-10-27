import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/validadores.dart';
import '../../../../shared/widgets/boton_principal.dart';
import '../../../../shared/widgets/campo_contrasena.dart';
import '../../../../shared/widgets/mensaje_error.dart';
import '../../domain/datos_registro.dart';
import '../acciones_sesion.dart';

/// Registro de cliente hogar (RF-01) o empresa cliente (RF-06, SCRUM-67).
/// La empresa se registra con su razón social, su NIT y su contacto
/// corporativo, y quien la registra queda como su primer usuario
/// (`POST /v1/auth/register/company`, identity 1.8.0). Al terminar inicia
/// sesión y el router lleva al inicio.
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
  final _correoContacto = TextEditingController();
  final _telefonoContacto = TextEditingController();
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
      _correoContacto,
      _telefonoContacto,
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
          .read(accionesSesionProvider)
          .registrarEIniciarSesion(
            DatosRegistro(
              tipo: _tipo,
              nombreCompleto: _nombre.text,
              email: _email.text,
              password: _password.text,
              telefono: _telefono.text,
              razonSocial: _razonSocial.text,
              nit: _nit.text,
              correoContacto: _correoContacto.text,
              telefonoContacto: _telefonoContacto.text,
            ),
          );
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Error del backend para [campo]. En el registro de empresa los errores
  /// llegan con prefijo (`company.nit`, `user.email`); un `409` se muestra
  /// junto al dato repetido.
  String? _errorDe(String campo) {
    final error = _error;
    if (error == null) return null;
    if (campo == 'nit' && error.esProblema('nit-registrado')) {
      return 'Ya hay una empresa registrada con este NIT.';
    }
    if (campo == 'email' && error.esProblema('correo-registrado')) {
      return 'Ya hay una cuenta con este correo.';
    }
    const deEmpresa = {'legalName', 'nit', 'contactEmail', 'contactPhone'};
    final prefijo = deEmpresa.contains(campo) ? 'company.' : 'user.';
    return error.errorDe('$prefijo$campo') ?? error.errorDe(campo);
  }

  /// Muestra junto al campo el error que devolvió el backend para ese campo.
  InputDecoration _decoracion(String etiqueta, String campo, IconData icono) =>
      InputDecoration(
        labelText: etiqueta,
        errorText: _errorDe(campo),
        prefixIcon: Icon(icono),
      );

  /// Un `409` ya se explica junto al dato repetido; los demás errores
  /// también se resumen debajo del formulario.
  bool get _errorGeneral =>
      _error != null &&
      !_error!.esProblema('nit-registrado') &&
      !_error!.esProblema('correo-registrado');

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
                  const SizedBox(height: QpEspacio.e5),
                  if (esEmpresa) ...[
                    const _Seccion('Tu empresa'),
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
                      keyboardType: TextInputType.phone,
                      validator: validarNit,
                    ),
                    const SizedBox(height: QpEspacio.e4),
                    TextFormField(
                      key: const Key('campo-correo-contacto'),
                      controller: _correoContacto,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _decoracion(
                        'Correo de contacto de la empresa',
                        'contactEmail',
                        Icons.alternate_email_rounded,
                      ),
                      validator: validarEmail,
                    ),
                    const SizedBox(height: QpEspacio.e4),
                    TextFormField(
                      key: const Key('campo-telefono-contacto'),
                      controller: _telefonoContacto,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: _decoracion(
                        'Teléfono de la empresa (opcional)',
                        'contactPhone',
                        Icons.call_outlined,
                      ),
                      validator: (v) => (v ?? '').trim().length > 30
                          ? 'Máximo 30 caracteres.'
                          : null,
                    ),
                    const SizedBox(height: QpEspacio.e6),
                  ],
                  const _Seccion('Tus datos'),
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
                    textoError: _errorDe('password'),
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
                  if (_errorGeneral) ...[
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
