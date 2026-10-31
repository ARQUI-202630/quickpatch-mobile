import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/session/controlador_sesion.dart';
import '../../../../shared/widgets/boton_principal.dart';
import '../../../../shared/widgets/confirmar_salida.dart';
import '../../../../shared/widgets/mensaje_error.dart';
import '../../../../shared/widgets/vista_error.dart';
import '../../data/repositorio_perfil.dart';
import '../../domain/perfil.dart';
import 'cuenta_page.dart';

/// Edición del perfil propio (SCRUM-609 / SCRUM-612). Contrato:
/// `GET` y `PATCH /v1/users/me` (identity 1.9.0). Solo se editan el nombre y
/// el teléfono; el correo y el rol se muestran sin poder cambiarlos. Al
/// guardar, el nombre nuevo pasa a la sesión y la pantalla se cierra. Si hay
/// cambios sin guardar, salir pide confirmación con [ConfirmarSalida] (SCRUM-617).
class EditarPerfilPage extends ConsumerStatefulWidget {
  const EditarPerfilPage({super.key});

  @override
  ConsumerState<EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends ConsumerState<EditarPerfilPage> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  Perfil? _perfil;
  bool _cargando = true;
  Object? _errorCarga;
  bool _guardando = false;
  AppException? _error;

  @override
  void initState() {
    super.initState();
    _nombre.addListener(_alEditar);
    _telefono.addListener(_alEditar);
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [_nombre, _telefono]) {
      c.dispose();
    }
    super.dispose();
  }

  void _alEditar() => setState(() {});

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final perfil = await ref.read(repositorioPerfilProvider).obtener();
      if (!mounted) return;
      _nombre.text = perfil.nombreCompleto;
      _telefono.text = perfil.telefono ?? '';
      setState(() => _perfil = perfil);
    } catch (e) {
      // También una respuesta que no se pudo leer: la pantalla ofrece
      // reintentar en lugar de quedarse sin contenido.
      if (mounted) setState(() => _errorCarga = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  CambiosPerfil? get _cambios {
    final perfil = _perfil;
    if (perfil == null) return null;
    final cambios = CambiosPerfil.entre(
      perfil,
      nombreCompleto: _nombre.text,
      telefono: _telefono.text,
    );
    return cambios.vacio ? null : cambios;
  }

  Future<void> _guardar() async {
    final cambios = _cambios;
    if (cambios == null) return;
    setState(() => _error = null);
    if (!_formulario.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final perfil = await ref
          .read(repositorioPerfilProvider)
          .actualizar(cambios);
      await ref
          .read(controladorSesionProvider.notifier)
          .actualizarNombre(perfil.nombreCompleto);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Perfil actualizado.')));
      // `context.pop` cierra sin pasar por [ConfirmarSalida].
      context.pop();
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  bool get _errorGeneral => _error != null && _error!.erroresCampo.isEmpty;

  @override
  Widget build(BuildContext context) {
    return ConfirmarSalida(
      hayCambios: () => _cambios != null,
      child: Scaffold(
        appBar: AppBar(title: const Text('Editar perfil')),
        body: SafeArea(child: _contenido()),
      ),
    );
  }

  Widget _contenido() {
    if (_cargando) {
      return const IndicadorCarga(etiqueta: 'Cargando tu perfil');
    }
    final perfil = _perfil;
    if (perfil == null) {
      return Center(
        child: SingleChildScrollView(
          child: VistaError(
            key: const Key('error-perfil'),
            error: _errorCarga!,
            titulo: 'No pudimos cargar tu perfil.',
            alReintentar: _cargar,
          ),
        ),
      );
    }
    final esquema = Theme.of(context).colorScheme;
    return SingleChildScrollView(
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
            Card(
              child: Column(
                children: [
                  ListTile(
                    key: const Key('perfil-correo'),
                    leading: const Icon(Icons.mail_outline_rounded),
                    title: const Text('Correo'),
                    subtitle: Text(perfil.email),
                    trailing: Icon(
                      Icons.lock_outline_rounded,
                      color: esquema.onSurfaceVariant,
                      semanticLabel: 'No se puede cambiar',
                    ),
                  ),
                  ListTile(
                    key: const Key('perfil-rol'),
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Rol'),
                    subtitle: Text(etiquetaRol(perfil.rol)),
                    trailing: Icon(
                      Icons.lock_outline_rounded,
                      color: esquema.onSurfaceVariant,
                      semanticLabel: 'No se puede cambiar',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: QpEspacio.e5),
            TextFormField(
              key: const Key('campo-nombre'),
              controller: _nombre,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nombre completo',
                errorText: _error?.errorDe('fullName'),
                prefixIcon: const Icon(Icons.person_outline_rounded),
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
              key: const Key('campo-telefono'),
              controller: _telefono,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _guardar(),
              decoration: InputDecoration(
                labelText: 'Teléfono (opcional)',
                errorText: _error?.errorDe('phone'),
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return null;
                if (t.length < 7) return 'Mínimo 7 caracteres.';
                if (t.length > 30) return 'Máximo 30 caracteres.';
                return null;
              },
            ),
            if (_errorGeneral) ...[
              const SizedBox(height: QpEspacio.e4),
              MensajeError(_error!.mensaje, key: const Key('mensaje-error')),
            ],
            const SizedBox(height: QpEspacio.e6),
            BotonPrincipal(
              key: const Key('boton-guardar'),
              texto: 'Guardar cambios',
              cargando: _guardando,
              alPresionar: _cambios == null ? null : _guardar,
            ),
          ],
        ),
      ),
    );
  }
}
