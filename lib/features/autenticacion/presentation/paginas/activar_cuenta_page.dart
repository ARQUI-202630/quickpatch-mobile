import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../shared/widgets/boton_principal.dart';
import '../../../../shared/widgets/campo_contrasena.dart';
import '../../../../shared/widgets/mensaje_error.dart';
import '../../../../shared/widgets/vista_estado.dart';
import '../../data/repositorio_activacion.dart';
import '../../domain/enlace_invitacion.dart';
import 'registro_page.dart' show validarContrasena;

/// Activación de la cuenta de un técnico del equipo de un proveedor
/// (SCRUM-98, identity 1.7.0): define su contraseña con la invitación.
///
/// Llega de dos formas: abriendo el enlace que le compartió el proveedor
/// (Android lo entrega en `/activar#token=...` y [token] viene lleno) o desde
/// el inicio de sesión, donde pega el enlace. La segunda funciona aunque el
/// enlace se abra en el navegador. No inicia sesión: al terminar lo envía al
/// inicio de sesión.
class ActivarCuentaPage extends ConsumerStatefulWidget {
  const ActivarCuentaPage({super.key, this.token});

  /// Token leído del enlace, si la app se abrió con él.
  final String? token;

  @override
  ConsumerState<ActivarCuentaPage> createState() => _ActivarCuentaPageState();
}

class _ActivarCuentaPageState extends ConsumerState<ActivarCuentaPage> {
  final _formulario = GlobalKey<FormState>();
  final _enlace = TextEditingController();
  final _password = TextEditingController();
  final _confirmacion = TextEditingController();
  bool _enviando = false;
  bool _activada = false;
  AppException? _error;

  @override
  void dispose() {
    for (final c in [_enlace, _password, _confirmacion]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _pideEnlace => widget.token == null;

  Future<void> _enviar() async {
    setState(() => _error = null);
    if (!_formulario.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      await ref
          .read(repositorioActivacionProvider)
          .definirContrasena(
            token: widget.token ?? tokenDeInvitacion(_enlace.text)!,
            password: _password.text,
          );
      if (mounted) setState(() => _activada = true);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// El enlace usado, vencido o anulado responde igual, a propósito, para no
  /// revelar cuál fue el caso: el técnico solo puede pedir uno nuevo.
  String? get _mensajeError {
    final error = _error;
    if (error == null || error.errorDe('password') != null) return null;
    if (error.esProblema('enlace-invalido')) {
      return 'El enlace no es válido o ya venció. Pide a tu proveedor que '
          'genere uno nuevo.';
    }
    return error.mensaje;
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final secundario = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Activa tu cuenta')),
      body: SafeArea(
        child: _activada
            ? Center(
                child: SingleChildScrollView(
                  child: VistaEstado(
                    key: const Key('cuenta-activada'),
                    icono: Icons.verified_user_outlined,
                    titulo: 'Tu cuenta está activa',
                    mensaje:
                        'Ya puedes iniciar sesión con tu correo y la '
                        'contraseña que acabas de definir.',
                    accion: 'Iniciar sesión',
                    alAccionar: () => context.go(Rutas.iniciarSesion),
                  ),
                ),
              )
            : SingleChildScrollView(
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
                          _pideEnlace
                              ? 'Tu proveedor te agregó a su equipo y te '
                                    'compartió un enlace. Pégalo aquí y define '
                                    'tu contraseña.'
                              : 'Tu proveedor te agregó a su equipo. Define '
                                    'tu contraseña para entrar a QUICKPATCH.',
                          style: texto.bodyMedium?.copyWith(color: secundario),
                        ),
                        const SizedBox(height: QpEspacio.e5),
                        if (_pideEnlace) ...[
                          TextFormField(
                            key: const Key('campo-enlace'),
                            controller: _enlace,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Enlace de invitación',
                              prefixIcon: Icon(Icons.link_rounded),
                            ),
                            validator: (v) => tokenDeInvitacion(v ?? '') == null
                                ? 'Pega el enlace completo que te compartió '
                                      'tu proveedor.'
                                : null,
                          ),
                          const SizedBox(height: QpEspacio.e4),
                        ],
                        CampoContrasena(
                          key: const Key('campo-password'),
                          controlador: _password,
                          etiqueta: 'Contraseña nueva',
                          accionTeclado: TextInputAction.next,
                          pistasAutocompletado: const [
                            AutofillHints.newPassword,
                          ],
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
                          pistasAutocompletado: const [
                            AutofillHints.newPassword,
                          ],
                          alEnviar: (_) => _enviar(),
                          validador: (v) => v == _password.text
                              ? null
                              : 'Las contraseñas no coinciden.',
                        ),
                        if (_mensajeError case final mensaje?) ...[
                          const SizedBox(height: QpEspacio.e4),
                          MensajeError(
                            mensaje,
                            key: const Key('mensaje-error'),
                          ),
                        ],
                        const SizedBox(height: QpEspacio.e6),
                        BotonPrincipal(
                          key: const Key('boton-activar'),
                          texto: 'Activar cuenta',
                          cargando: _enviando,
                          alPresionar: _enviar,
                        ),
                        const SizedBox(height: QpEspacio.e2),
                        TextButton(
                          onPressed: () => context.go(Rutas.iniciarSesion),
                          child: const Text('Ya tengo contraseña'),
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
