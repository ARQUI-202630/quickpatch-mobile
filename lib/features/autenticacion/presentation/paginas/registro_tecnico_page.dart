import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/catalogo/repositorio_catalogo.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/validadores.dart';
import '../../../../shared/widgets/boton_principal.dart';
import '../../../../shared/widgets/campo_contrasena.dart';
import '../../../../shared/widgets/mensaje_error.dart';
import '../../../../shared/widgets/selector_categoria.dart';
import '../../../../shared/widgets/vista_error.dart';
import '../../domain/datos_registro.dart';
import '../acciones_sesion.dart';

/// Registro de técnico o proveedor (RF-02, SCRUM-22 / SCRUM-55).
///
/// Contrato: `POST /v1/auth/register/technician` (identity.v1.yaml). La
/// especialidad sale de las categorías activas del tenant del canal
/// (`GET /v1/catalog/categories` sin sesión, con `X-Channel-Id`). El tenant
/// nunca se pide: sale del canal (RN-U5). Al terminar inicia sesión y el
/// inicio le muestra que su cuenta está en verificación.
class RegistroTecnicoPage extends ConsumerStatefulWidget {
  const RegistroTecnicoPage({super.key});

  @override
  ConsumerState<RegistroTecnicoPage> createState() =>
      _RegistroTecnicoPageState();
}

class _RegistroTecnicoPageState extends ConsumerState<RegistroTecnicoPage> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  final _documento = TextEditingController();
  final _password = TextEditingController();
  final _confirmacion = TextEditingController();
  RolProfesional _rol = RolProfesional.tecnico;
  String? _especialidad;
  bool _enviando = false;
  AppException? _error;

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _email,
      _telefono,
      _documento,
      _password,
      _confirmacion,
    ]) {
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
      await ref
          .read(accionesSesionProvider)
          .registrarTecnicoEIniciarSesion(
            DatosRegistroTecnico(
              rol: _rol,
              nombreCompleto: _nombre.text,
              email: _email.text,
              password: _password.text,
              telefono: _telefono.text,
              documento: _documento.text,
              especialidadId: _especialidad!,
            ),
          );
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Error del backend para [campo]: el del `400` o, en un `409`, el del
  /// dato repetido (correo o documento) junto al campo que lo causó.
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
      appBar: AppBar(title: const Text('Registro de técnico o proveedor')),
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
                    'Ofrece tus servicios en QUICKPATCH. Un administrador '
                    'revisará tus datos antes de que recibas solicitudes.',
                    style: texto.bodyMedium?.copyWith(color: secundario),
                  ),
                  const SizedBox(height: QpEspacio.e5),
                  const _Seccion('¿Cómo vas a trabajar?'),
                  SegmentedButton<RolProfesional>(
                    key: const Key('selector-rol'),
                    segments: const [
                      ButtonSegment(
                        value: RolProfesional.tecnico,
                        label: Text('Técnico'),
                        icon: Icon(Icons.handyman_outlined),
                      ),
                      ButtonSegment(
                        value: RolProfesional.proveedor,
                        label: Text('Proveedor'),
                        icon: Icon(Icons.groups_outlined),
                      ),
                    ],
                    selected: {_rol},
                    onSelectionChanged: (s) => setState(() => _rol = s.first),
                  ),
                  const SizedBox(height: QpEspacio.e1),
                  Padding(
                    padding: const EdgeInsets.only(left: QpEspacio.e4),
                    child: Text(
                      _rol == RolProfesional.tecnico
                          ? 'Atiendes las solicitudes tú mismo.'
                          : 'Administras un equipo de técnicos.',
                      style: texto.bodySmall?.copyWith(color: secundario),
                    ),
                  ),
                  const SizedBox(height: QpEspacio.e6),
                  const _Seccion('Tus datos'),
                  TextFormField(
                    key: const Key('campo-nombre'),
                    controller: _nombre,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
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
                    textInputAction: TextInputAction.next,
                    decoration: _decoracion(
                      'Documento de identidad',
                      'documentId',
                      Icons.badge_outlined,
                    ),
                    validator: (v) => _longitud(v, 5, 30),
                  ),
                  const SizedBox(height: QpEspacio.e6),
                  const _Seccion('Tu especialidad'),
                  _Especialidad(
                    error: _errorDe('specialtyId'),
                    alElegir: (id) => setState(() => _especialidad = id),
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
                    key: const Key('boton-registrar-tecnico'),
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

/// Especialidad: las categorías activas del tenant del canal, con sus
/// estados de carga y error. Sin categorías no se puede enviar el registro.
class _Especialidad extends ConsumerWidget {
  const _Especialidad({required this.alElegir, this.error});

  final ValueChanged<String> alElegir;

  /// Error de `specialtyId` que devolvió el backend.
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categorias = ref.watch(categoriasPublicasProvider);
    final esquema = Theme.of(context).colorScheme;
    return categorias.when(
      loading: () => const IndicadorCarga(etiqueta: 'Cargando especialidades'),
      error: (e, _) => VistaError(
        key: const Key('error-especialidades'),
        error: e,
        titulo: 'No pudimos cargar las especialidades.',
        alReintentar: () => ref.invalidate(categoriasPublicasProvider),
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
                  mensajeObligatorio: 'Elige tu especialidad.',
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

/// Obligatorio y con los límites del contrato.
String? _longitud(String? valor, int minimo, int maximo) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return 'Es obligatorio.';
  if (texto.length < minimo) return 'Usa al menos $minimo caracteres.';
  if (texto.length > maximo) return 'Máximo $maximo caracteres.';
  return null;
}
