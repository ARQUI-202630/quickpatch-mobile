import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../shared/widgets/boton_principal.dart';
import '../../../../shared/widgets/campo_contrasena.dart';
import '../../../../shared/widgets/mensaje_error.dart';
import '../controlador_sesion.dart';

/// Inicio de sesión (RF-03). Contrato: `POST /v1/auth/login`.
class InicioSesionPage extends ConsumerStatefulWidget {
  const InicioSesionPage({super.key});

  @override
  ConsumerState<InicioSesionPage> createState() => _InicioSesionPageState();
}

class _InicioSesionPageState extends ConsumerState<InicioSesionPage> {
  final _formulario = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ref
          .read(controladorSesionProvider.notifier)
          .iniciarSesion(email: _email.text, password: _password.text);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: QpEspacio.pantalla,
              vertical: QpEspacio.e8,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const MarcaQuickpatch(),
                      const SizedBox(height: QpEspacio.e10),
                      Text('Inicia sesión', style: texto.headlineSmall),
                      const SizedBox(height: QpEspacio.e1),
                      Text(
                        'Pide un técnico o atiende tus servicios.',
                        style: texto.bodyMedium?.copyWith(
                          color: esquema.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: QpEspacio.e6),
                      TextFormField(
                        key: const Key('campo-email'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: validarEmail,
                      ),
                      const SizedBox(height: QpEspacio.e4),
                      CampoContrasena(
                        key: const Key('campo-password'),
                        controlador: _password,
                        etiqueta: 'Contraseña',
                        alEnviar: (_) => _enviar(),
                        validador: (v) => (v == null || v.isEmpty)
                            ? 'Escribe tu contraseña.'
                            : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: QpEspacio.e4),
                        MensajeError(_error!, key: const Key('mensaje-error')),
                      ],
                      const SizedBox(height: QpEspacio.e6),
                      BotonPrincipal(
                        key: const Key('boton-ingresar'),
                        texto: 'Ingresar',
                        cargando: _enviando,
                        alPresionar: _enviar,
                      ),
                      const SizedBox(height: QpEspacio.e6),
                      // Wrap: con texto grande el botón pasa a otra línea.
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '¿No tienes cuenta?',
                            style: texto.bodyMedium?.copyWith(
                              color: esquema.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            key: const Key('boton-ir-registro'),
                            onPressed: () => context.go(Rutas.registro),
                            child: const Text('Crear una cuenta'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Marca de QUICKPATCH: ícono sobre el azul de marca y el nombre.
class MarcaQuickpatch extends StatelessWidget {
  const MarcaQuickpatch({super.key});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: esquema.primary,
            borderRadius: BorderRadius.circular(QpRadio.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(QpEspacio.e3),
            child: Icon(Icons.bolt_rounded, size: 36, color: esquema.onPrimary),
          ),
        ),
        const SizedBox(height: QpEspacio.e3),
        Text(
          'QUICKPATCH',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}

/// Valida el correo antes de enviarlo (AC4, protección ante errores).
String? validarEmail(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return 'Escribe tu correo.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texto)) {
    return 'Escribe un correo válido, por ejemplo ana@correo.com.';
  }
  return null;
}
