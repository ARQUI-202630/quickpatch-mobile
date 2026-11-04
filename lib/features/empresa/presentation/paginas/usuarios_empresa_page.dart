import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/rutas.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../shared/widgets/hoja_invitacion.dart';
import '../../../../shared/widgets/vista_error.dart';
import '../../data/repositorio_empresa.dart';
import '../../domain/modelos.dart';

/// Usuarios de la empresa cliente (RF-06, SCRUM-26 / SCRUM-67): quiénes
/// pueden pedir servicios a nombre de la empresa. Desde aquí se agregan
/// usuarios y se genera un enlace nuevo para quien todavía no activó su
/// cuenta (identity 1.8.0).
class UsuariosEmpresaPage extends ConsumerStatefulWidget {
  const UsuariosEmpresaPage({super.key});

  @override
  ConsumerState<UsuariosEmpresaPage> createState() =>
      _UsuariosEmpresaPageState();
}

class _UsuariosEmpresaPageState extends ConsumerState<UsuariosEmpresaPage> {
  List<UsuarioEmpresa> _usuarios = const [];
  int _pagina = 0;
  int _total = 0;
  bool _cargando = true;
  bool _cargandoMas = false;
  Object? _error;
  String? _generando;

  RepositorioEmpresa get _repositorio => ref.read(repositorioEmpresaProvider);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final pagina = await _repositorio.usuarios();
      if (!mounted) return;
      setState(() {
        _usuarios = pagina.usuarios;
        _pagina = pagina.pagina;
        _total = pagina.total;
      });
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarMas() async {
    setState(() => _cargandoMas = true);
    try {
      final pagina = await _repositorio.usuarios(pagina: _pagina + 1);
      if (!mounted) return;
      setState(() {
        _usuarios = [..._usuarios, ...pagina.usuarios];
        _pagina = pagina.pagina;
        _total = pagina.total;
      });
    } on AppException catch (e) {
      _avisar(e.mensaje);
    } finally {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  Future<void> _agregar() async {
    final agregado = await context.push<bool>(Rutas.agregarUsuarioEmpresa);
    if (agregado == true && mounted) await _cargar();
  }

  Future<void> _nuevoEnlace(UsuarioEmpresa usuario) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('¿Generar un enlace nuevo para ${usuario.nombre}?'),
        content: const Text(
          'El enlace anterior dejará de funcionar. Úsalo si se perdió o se '
          'venció.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirmar-enlace-nuevo'),
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Generar enlace'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() => _generando = usuario.userId);
    try {
      final invitacion = await _repositorio.nuevaInvitacion(usuario.userId);
      if (!mounted) return;
      setState(() => _generando = null);
      await mostrarInvitacion(
        context,
        nombre: usuario.nombre,
        invitacion: invitacion,
        esNueva: true,
        explicacion: '',
        destino: DestinoInvitacion.empresa,
      );
    } on AppException catch (e) {
      if (e.esProblema('contrasena-definida')) {
        _avisar('${usuario.nombre} ya activó su cuenta.');
        await _cargar();
      } else {
        _avisar(e.mensaje);
      }
    } finally {
      if (mounted) setState(() => _generando = null);
    }
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Usuarios de la empresa')),
    floatingActionButton: _cargando || _error != null
        ? null
        : FloatingActionButton.extended(
            key: const Key('boton-agregar-usuario'),
            onPressed: _agregar,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Agregar usuario'),
          ),
    body: SafeArea(child: _contenido()),
  );

  Widget _contenido() {
    if (_cargando) {
      return const IndicadorCarga(etiqueta: 'Cargando los usuarios');
    }
    if (_error case final error?) {
      return Center(
        child: SingleChildScrollView(
          child: VistaError(
            key: const Key('error-usuarios-empresa'),
            error: error,
            titulo: 'No pudimos cargar los usuarios de tu empresa.',
            alReintentar: _cargar,
          ),
        ),
      );
    }
    final texto = Theme.of(context).textTheme;
    final secundario = Theme.of(context).colorScheme.onSurfaceVariant;
    return RefreshIndicator(
      onRefresh: () {
        ref.invalidate(empresaProvider);
        return _cargar();
      },
      child: ListView(
        key: const Key('lista-usuarios-empresa'),
        padding: const EdgeInsets.fromLTRB(
          QpEspacio.pantalla,
          QpEspacio.e2,
          QpEspacio.pantalla,
          // Espacio para que el botón flotante no tape el último usuario.
          QpEspacio.e12 * 2,
        ),
        children: [
          const _TarjetaEmpresa(),
          const SizedBox(height: QpEspacio.e4),
          Text(
            'Pueden pedir y seguir servicios a nombre de la empresa.',
            style: texto.bodyMedium?.copyWith(color: secundario),
          ),
          const SizedBox(height: QpEspacio.e2),
          Text(
            _total == 1 ? '1 usuario' : '$_total usuarios',
            key: const Key('total-usuarios-empresa'),
            style: texto.bodySmall?.copyWith(color: secundario),
          ),
          const SizedBox(height: QpEspacio.e2),
          for (final u in _usuarios)
            _TarjetaUsuario(
              usuario: u,
              generando: _generando == u.userId,
              alGenerarEnlace: _generando == null && !u.contrasenaDefinida
                  ? () => _nuevoEnlace(u)
                  : null,
            ),
          if (_usuarios.length < _total)
            Padding(
              padding: const EdgeInsets.only(top: QpEspacio.e2),
              child: OutlinedButton(
                key: const Key('boton-cargar-mas'),
                onPressed: _cargandoMas ? null : _cargarMas,
                child: Text(_cargandoMas ? 'Cargando…' : 'Cargar más'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Razón social y NIT. Si no carga, la lista de usuarios se ve igual.
class _TarjetaEmpresa extends ConsumerWidget {
  const _TarjetaEmpresa();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empresa = ref.watch(empresaProvider).value;
    if (empresa == null) return const SizedBox.shrink();
    return Card(
      key: const Key('tarjeta-empresa'),
      child: ListTile(
        leading: const Icon(Icons.business_rounded),
        title: Text(empresa.razonSocial),
        subtitle: Text('NIT ${empresa.nit}\n${empresa.correoContacto}'),
        isThreeLine: true,
      ),
    );
  }
}

class _TarjetaUsuario extends StatelessWidget {
  const _TarjetaUsuario({
    required this.usuario,
    required this.generando,
    required this.alGenerarEnlace,
  });

  final UsuarioEmpresa usuario;
  final bool generando;
  final VoidCallback? alGenerarEnlace;

  @override
  Widget build(BuildContext context) {
    final estados = context.estados;
    final (etiqueta, color, fondo) = usuario.contrasenaDefinida
        ? ('Activo', estados.exito, estados.exitoFondo)
        : ('Invitación pendiente', estados.aviso, estados.avisoFondo);
    return Card(
      key: Key('usuario-${usuario.userId}'),
      margin: const EdgeInsets.only(bottom: QpEspacio.e2),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          QpEspacio.e4,
          QpEspacio.e3,
          QpEspacio.e1,
          QpEspacio.e3,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usuario.nombre,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: QpEspacio.e1),
                  Text(
                    usuario.email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: QpEspacio.e2),
                  DecoratedBox(
                    key: Key(
                      usuario.contrasenaDefinida
                          ? 'estado-activo'
                          : 'estado-pendiente',
                    ),
                    decoration: BoxDecoration(
                      color: fondo,
                      borderRadius: BorderRadius.circular(QpRadio.pildora),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: QpEspacio.e3,
                        vertical: QpEspacio.e1,
                      ),
                      child: Text(
                        etiqueta,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: color),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (generando)
              const Padding(
                padding: EdgeInsets.all(QpEspacio.e3),
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (!usuario.contrasenaDefinida)
              IconButton(
                key: Key('enlace-${usuario.userId}'),
                tooltip: 'Generar enlace nuevo para ${usuario.nombre}',
                onPressed: alGenerarEnlace,
                icon: const Icon(Icons.link_rounded),
              ),
          ],
        ),
      ),
    );
  }
}
