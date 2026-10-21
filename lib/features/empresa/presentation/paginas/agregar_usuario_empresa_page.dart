import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/validadores.dart';
import '../../../../shared/widgets/boton_principal.dart';
import '../../../../shared/widgets/hoja_invitacion.dart';
import '../../../../shared/widgets/mensaje_error.dart';
import '../../data/repositorio_empresa.dart';
import '../../domain/modelos.dart';

/// Agrega otro usuario a la empresa (RF-06, SCRUM-26 criterio 3). Contrato:
/// `POST /v1/companies/me/users` (identity 1.8.0). Sin contraseña: el usuario
/// la define con la invitación que se muestra al terminar (RN-CC4). Devuelve
/// `true` al cerrar si agregó a alguien.
class AgregarUsuarioEmpresaPage extends ConsumerStatefulWidget {
  const AgregarUsuarioEmpresaPage({super.key});

  @override
  ConsumerState<AgregarUsuarioEmpresaPage> createState() =>
      _AgregarUsuarioEmpresaPageState();
}

class _AgregarUsuarioEmpresaPageState
    extends ConsumerState<AgregarUsuarioEmpresaPage> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  bool _enviando = false;
  AppException? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _email, _telefono]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _error = null);
    if (!_formulario.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      final creado = await ref
          .read(repositorioEmpresaProvider)
          .agregar(
            DatosUsuarioEmpresa(
              nombreCompleto: _nombre.text,
              email: _email.text,
              telefono: _telefono.text,
            ),
          );
      if (!mounted) return;
      // Ya terminó: el botón deja de cargar mientras se ve la invitación.
      setState(() => _enviando = false);
      await mostrarInvitacion(
        context,
        nombre: creado.nombre,
        invitacion: creado.invitacion,
        esNueva: false,
        explicacion:
            '${creado.nombre} ya puede pedir servicios a nombre de tu empresa. '
            'Compártele este enlace para que defina su contraseña.',
        destino: DestinoInvitacion.empresa,
      );
      if (mounted) context.pop(true);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String? _errorDe(String campo) {
    final error = _error;
    if (error == null) return null;
    if (campo == 'email' && error.esProblema('correo-registrado')) {
      return 'Ya hay una cuenta con este correo.';
    }
    return error.errorDe(campo);
  }

  bool get _errorGeneral =>
      _error != null &&
      _error!.erroresCampo.isEmpty &&
      !_error!.esProblema('correo-registrado');

  InputDecoration _decoracion(String etiqueta, String campo, IconData icono) =>
      InputDecoration(
        labelText: etiqueta,
        errorText: _errorDe(campo),
        prefixIcon: Icon(icono),
      );

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar usuario')),
      body: SafeArea(
        child: SingleChildScrollView(
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
                  'Podrá pedir y seguir servicios a nombre de tu empresa. Al '
                  'terminar te daremos un enlace para que defina su '
                  'contraseña.',
                  style: texto.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: QpEspacio.e5),
                TextFormField(
                  key: const Key('campo-nombre'),
                  controller: _nombre,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoracion(
                    'Nombre completo',
                    'fullName',
                    Icons.person_outline_rounded,
                  ),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.length < 2) return 'Mínimo 2 caracteres.';
                    if (t.length > 150) return 'Máximo 150 caracteres.';
                    return null;
                  },
                ),
                const SizedBox(height: QpEspacio.e4),
                TextFormField(
                  key: const Key('campo-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
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
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _enviar(),
                  decoration: _decoracion(
                    'Teléfono (opcional)',
                    'phone',
                    Icons.phone_outlined,
                  ),
                  validator: (v) => (v ?? '').trim().length > 30
                      ? 'Máximo 30 caracteres.'
                      : null,
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
                  key: const Key('boton-agregar'),
                  texto: 'Agregar usuario',
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
