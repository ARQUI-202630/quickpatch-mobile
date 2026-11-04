import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/codigo_error.dart';
import '../../../../core/utils/validadores.dart';
import '../../../../shared/widgets/boton_principal.dart';
import '../../../../shared/widgets/confirmar_salida.dart';
import '../../../../shared/widgets/mensaje_error.dart';
import '../../../../shared/widgets/vista_estado.dart';
import '../../data/repositorio_activacion.dart';

/// Pedir la recuperación de la contraseña olvidada, desde el inicio de sesión
/// (SCRUM-626, identity 1.10.0). El correo sigue fuera del MVP (ADR-024): el
/// administrador ve la solicitud, confirma que es el usuario y le entrega un
/// enlace que vence en 1 hora y se abre en el panel web.
///
/// La respuesta es la misma exista o no la cuenta, para no revelar quién está
/// registrado; la pantalla también.
class RecuperarContrasenaPage extends ConsumerStatefulWidget {
  const RecuperarContrasenaPage({super.key, this.email});

  /// Correo que el usuario ya escribió en el inicio de sesión, si lo hay.
  final String? email;

  @override
  ConsumerState<RecuperarContrasenaPage> createState() =>
      _RecuperarContrasenaPageState();
}

class _RecuperarContrasenaPageState
    extends ConsumerState<RecuperarContrasenaPage> {
  final _formulario = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email?.trim());
  late final _inicial = _email.text;
  bool _enviando = false;
  bool _enviada = false;
  AppException? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _error = null);
    if (!_formulario.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      await ref.read(repositorioRecuperacionProvider).pedir(_email.text);
      if (mounted) setState(() => _enviada = true);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Mensaje general; los errores del correo van bajo el campo.
  String? get _mensajeError {
    final error = _error;
    if (error == null || error.errorDe('email') != null) return null;
    if (error.codigo == CodigoError.tooManyRequests) {
      final espera = error.reintentarEn;
      if (espera == null) return error.mensaje;
      final minutos = (espera.inSeconds / 60).ceil().clamp(1, 60);
      return 'Ya pediste la recuperación varias veces. Intenta de nuevo en '
          '${minutos == 1 ? '1 minuto' : '$minutos minutos'}.';
    }
    return error.mensaje;
  }

  @override
  Widget build(BuildContext context) => ConfirmarSalida(
    // El correo que llegó del inicio de sesión no cuenta como cambio.
    hayCambios: () => !_enviada && _email.text.trim() != _inicial,
    cambios: _email,
    child: _contenido(context),
  );

  Widget _contenido(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final secundario = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Recupera tu contraseña')),
      body: SafeArea(
        child: _enviada
            ? Center(
                child: SingleChildScrollView(
                  child: VistaEstado(
                    key: const Key('recuperacion-enviada'),
                    icono: Icons.mark_email_read_outlined,
                    titulo: 'Recibimos tu solicitud',
                    mensaje:
                        'Si el correo está registrado, el administrador te '
                        'contactará para confirmar que eres tú y te hará '
                        'llegar un enlace para definir una contraseña nueva. '
                        'El enlace vence en 1 hora.',
                    accion: 'Volver a iniciar sesión',
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
                child: Form(
                  key: _formulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Escribe el correo de tu cuenta. El administrador '
                        'recibirá tu solicitud y te hará llegar un enlace '
                        'para definir una contraseña nueva.',
                        style: texto.bodyMedium?.copyWith(color: secundario),
                      ),
                      const SizedBox(height: QpEspacio.e5),
                      TextFormField(
                        key: const Key('campo-email'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.send,
                        autocorrect: false,
                        onFieldSubmitted: (_) => _enviar(),
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: const Icon(Icons.mail_outline_rounded),
                          errorText: _error?.errorDe('email'),
                        ),
                        validator: validarEmail,
                      ),
                      if (_mensajeError case final mensaje?) ...[
                        const SizedBox(height: QpEspacio.e4),
                        MensajeError(mensaje, key: const Key('mensaje-error')),
                      ],
                      const SizedBox(height: QpEspacio.e6),
                      BotonPrincipal(
                        key: const Key('boton-recuperar'),
                        texto: 'Pedir recuperación',
                        cargando: _enviando,
                        alPresionar: _enviar,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
