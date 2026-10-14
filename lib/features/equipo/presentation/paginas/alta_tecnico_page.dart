import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../shared/widgets/boton_principal.dart';
import '../../../../shared/widgets/mensaje_error.dart';
import '../../../../shared/widgets/vista_error.dart';
import '../../../autenticacion/presentation/paginas/inicio_sesion_page.dart'
    show validarEmail;
import '../../../solicitudes/data/repositorio_solicitudes.dart';
import '../../../solicitudes/presentation/widgets/selector_categoria.dart';
import '../../data/repositorio_equipo.dart';
import '../../domain/modelos.dart';
import '../widgets/hoja_invitacion.dart';

/// Alta de un técnico en el equipo del proveedor (RF-16, SCRUM-98).
///
/// Contrato: `POST /v1/providers/me/technicians` (identity 1.7.0). Pide los
/// mismos datos que el registro de técnico, sin contraseña: el técnico la
/// define con la invitación que se muestra al terminar. Queda pendiente de
/// verificación hasta que el administrador lo apruebe (RN-TP1). Devuelve
/// `true` al cerrar si dio de alta a alguien.
class AltaTecnicoPage extends ConsumerStatefulWidget {
  const AltaTecnicoPage({super.key});

  @override
  ConsumerState<AltaTecnicoPage> createState() => _AltaTecnicoPageState();
}

class _AltaTecnicoPageState extends ConsumerState<AltaTecnicoPage> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  final _documento = TextEditingController();
  String? _especialidad;
  bool _enviando = false;
  AppException? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _email, _telefono, _documento]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _error = null);
    if (!_formulario.currentState!.validate() || _especialidad == null) {
      return;
    }
    setState(() => _enviando = true);
    try {
      final creado = await ref
          .read(repositorioEquipoProvider)
          .darDeAlta(
            DatosAltaTecnico(
              nombreCompleto: _nombre.text,
              email: _email.text,
              telefono: _telefono.text,
              documento: _documento.text,
              especialidadId: _especialidad!,
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
      );
      if (mounted) context.pop(true);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Error del backend para [campo]: el del `400` o, en un `409`, el del
  /// dato repetido junto al campo que lo causó.
  String? _errorDe(String campo) {
    final error = _error;
    if (error == null) return null;
    if (campo == 'email' && error.esProblema('correo-registrado')) {
      return 'Ya hay una cuenta con este correo.';
    }
    if (campo == 'documentId' && error.esProblema('documento-registrado')) {
      return 'Ya hay una cuenta con este documento.';
    }
    return error.errorDe(campo);
  }

  /// El mensaje general solo aparece si el error no quedó junto a un campo.
  bool get _errorGeneral =>
      _error != null &&
      _error!.erroresCampo.isEmpty &&
      !_error!.esProblema('correo-registrado') &&
      !_error!.esProblema('documento-registrado');

  InputDecoration _decoracion(String etiqueta, String campo, IconData icono) =>
      InputDecoration(
        labelText: etiqueta,
        errorText: _errorDe(campo),
        prefixIcon: Icon(icono),
      );

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final secundario = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar técnico')),
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
                  'El técnico quedará en tu equipo pendiente de que el '
                  'administrador lo apruebe. Al terminar te daremos un enlace '
                  'para que defina su contraseña.',
                  style: texto.bodyMedium?.copyWith(color: secundario),
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
                  validator: (v) => _longitud(v, 2, 150),
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
                  textInputAction: TextInputAction.next,
                  decoration: _decoracion(
                    'Teléfono',
                    'phone',
                    Icons.phone_outlined,
                  ),
                  validator: (v) => _longitud(v, 7, 30),
                ),
                const SizedBox(height: QpEspacio.e4),
                TextFormField(
                  key: const Key('campo-documento'),
                  controller: _documento,
                  textInputAction: TextInputAction.done,
                  decoration: _decoracion(
                    'Documento de identidad',
                    'documentId',
                    Icons.badge_outlined,
                  ),
                  validator: (v) => _longitud(v, 5, 30),
                ),
                const SizedBox(height: QpEspacio.e6),
                Semantics(
                  header: true,
                  child: Text('Especialidad', style: texto.titleSmall),
                ),
                const SizedBox(height: QpEspacio.e3),
                _Especialidad(
                  error: _errorDe('specialtyId'),
                  alElegir: (id) => setState(() => _especialidad = id),
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
                  key: const Key('boton-guardar-tecnico'),
                  texto: 'Agregar técnico',
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

/// Especialidad: las categorías activas del tenant del proveedor.
class _Especialidad extends ConsumerWidget {
  const _Especialidad({required this.alElegir, this.error});

  final ValueChanged<String> alElegir;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categorias = ref.watch(categoriasProvider);
    final esquema = Theme.of(context).colorScheme;
    return categorias.when(
      loading: () => const IndicadorCarga(etiqueta: 'Cargando especialidades'),
      error: (e, _) => VistaError(
        key: const Key('error-especialidades'),
        error: e,
        titulo: 'No pudimos cargar las especialidades.',
        alReintentar: () => ref.invalidate(categoriasProvider),
      ),
      data: (lista) => lista.isEmpty
          ? Text(
              'Todavía no hay especialidades disponibles.',
              key: const Key('sin-especialidades'),
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectorCategoria(
                  key: const Key('campo-especialidad'),
                  categorias: lista,
                  mensajeObligatorio: 'Elige su especialidad.',
                  alElegir: alElegir,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: QpEspacio.e2,
                      left: QpEspacio.e4,
                    ),
                    child: Text(
                      error!,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: esquema.error),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Obligatorio y con los límites del contrato.
String? _longitud(String? valor, int minimo, int maximo) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return 'Es obligatorio.';
  if (texto.length < minimo) return 'Usa al menos $minimo caracteres.';
  if (texto.length > maximo) return 'Máximo $maximo caracteres.';
  return null;
}
