import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/catalogo/categoria.dart';
import '../../core/catalogo/repositorio_catalogo.dart';
import '../../core/session/rol_usuario.dart';
import '../../core/session/sesion.dart';
import '../../features/autenticacion/presentation/controlador_sesion.dart';
import '../../shared/widgets/icono_categoria.dart';
import '../../shared/widgets/vista_error.dart';
import '../../shared/widgets/vista_estado.dart';
import '../router/rutas.dart';
import '../theme/tokens.dart';
import 'opciones_por_rol.dart';

/// Pantalla de inicio según el rol del usuario autenticado (SCRUM-441).
///
/// El cliente ve un acceso directo a la nueva solicitud y las categorías de
/// servicio que entrega Catalog (`GET /v1/catalog/categories`); al tocar una,
/// la solicitud se abre con esa categoría elegida. Los demás roles ven sus
/// opciones, habilitadas a medida que se implementa cada feature.
class InicioPage extends ConsumerWidget {
  const InicioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(controladorSesionProvider).value;
    if (sesion == null) return const SizedBox.shrink();
    final usuario = sesion.usuario;

    if (!usuario.rol.usaAppMovil) {
      return Scaffold(
        appBar: AppBar(title: Text('Hola, ${usuario.fullName}')),
        body: const VistaEstado(
          key: Key('mensaje-admin'),
          icono: Icons.desktop_windows_outlined,
          titulo: 'La administración se hace desde el panel web de QUICKPATCH.',
        ),
      );
    }

    final opciones = opcionesPara(usuario.rol);
    final puedeSolicitar = opciones.any((o) => o.ruta == Rutas.nuevaSolicitud);
    final otras = opciones.where((o) => o.ruta != Rutas.nuevaSolicitud);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                QpEspacio.pantalla,
                QpEspacio.e6,
                QpEspacio.pantalla,
                QpEspacio.e2,
              ),
              sliver: SliverList.list(
                children: [
                  _Saludo(usuario: usuario, puedeSolicitar: puedeSolicitar),
                  if (_enVerificacion(usuario)) ...[
                    const SizedBox(height: QpEspacio.e5),
                    const _AvisoVerificacion(),
                  ],
                  if (puedeSolicitar) ...[
                    const SizedBox(height: QpEspacio.e6),
                    const _TarjetaSolicitar(),
                    const SizedBox(height: QpEspacio.e8),
                    _TituloSeccion('Categorías de servicio'),
                    const SizedBox(height: QpEspacio.e3),
                  ],
                ],
              ),
            ),
            if (puedeSolicitar) const _Categorias(),
            if (otras.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  QpEspacio.pantalla,
                  QpEspacio.e8,
                  QpEspacio.pantalla,
                  QpEspacio.e8,
                ),
                sliver: SliverList.list(
                  children: [
                    _TituloSeccion(
                      puedeSolicitar ? 'Más opciones' : 'Tus opciones',
                    ),
                    const SizedBox(height: QpEspacio.e3),
                    for (final opcion in otras) ...[
                      _TarjetaOpcion(opcion),
                      const SizedBox(height: QpEspacio.e3),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static bool _enVerificacion(UsuarioSesion usuario) =>
      (usuario.rol == RolUsuario.tecnico ||
          usuario.rol == RolUsuario.proveedor) &&
      usuario.verificationStatus != null &&
      usuario.verificationStatus != 'aprobado';
}

class _Saludo extends StatelessWidget {
  const _Saludo({required this.usuario, required this.puedeSolicitar});

  final UsuarioSesion usuario;
  final bool puedeSolicitar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final subtitulo = switch (usuario.rol) {
      _ when puedeSolicitar => '¿Qué necesitas arreglar hoy?',
      RolUsuario.tecnico => 'Tu trabajo en QUICKPATCH',
      RolUsuario.proveedor => 'Tu equipo en QUICKPATCH',
      _ => 'Bienvenido a QUICKPATCH',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hola, ${usuario.fullName}', style: texto.headlineSmall),
        const SizedBox(height: QpEspacio.e1),
        Text(
          subtitulo,
          style: texto.bodyLarge?.copyWith(color: esquema.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _AvisoVerificacion extends StatelessWidget {
  const _AvisoVerificacion();

  @override
  Widget build(BuildContext context) {
    final estados = context.estados;
    final texto = Theme.of(context).textTheme;
    return DecoratedBox(
      key: const Key('aviso-verificacion'),
      decoration: BoxDecoration(
        color: estados.avisoFondo,
        borderRadius: BorderRadius.circular(QpRadio.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(QpEspacio.e4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.hourglass_top_rounded, color: estados.aviso),
            const SizedBox(width: QpEspacio.e3),
            Expanded(
              child: Text(
                'Tu cuenta está en verificación. Te avisaremos cuando un '
                'administrador la apruebe.',
                style: texto.bodyMedium?.copyWith(color: estados.aviso),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaSolicitar extends StatelessWidget {
  const _TarjetaSolicitar();

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: esquema.primary,
        borderRadius: BorderRadius.circular(QpRadio.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(QpEspacio.e5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.bolt_rounded, color: esquema.onPrimary, size: 28),
            const SizedBox(height: QpEspacio.e3),
            Text(
              'Un técnico verificado, cerca de ti',
              style: texto.titleLarge?.copyWith(color: esquema.onPrimary),
            ),
            const SizedBox(height: QpEspacio.e1),
            Text(
              'Cuéntanos qué pasa y dónde estás; buscamos al técnico '
              'disponible.',
              style: texto.bodyMedium?.copyWith(color: esquema.onPrimary),
            ),
            const SizedBox(height: QpEspacio.e5),
            FilledButton.icon(
              key: const Key('boton-nueva-solicitud'),
              style: FilledButton.styleFrom(
                backgroundColor: esquema.onPrimary,
                foregroundColor: esquema.primary,
              ),
              onPressed: () => context.push(Rutas.nuevaSolicitud),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva solicitud'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(titulo, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// Cuadrícula de categorías de Catalog, con sus estados de carga, error y
/// vacío.
class _Categorias extends ConsumerWidget {
  const _Categorias();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categorias = ref.watch(categoriasProvider);
    Widget enCaja(Widget hijo) => SliverToBoxAdapter(child: hijo);

    return categorias.when(
      loading: () => enCaja(
        const Padding(
          padding: EdgeInsets.all(QpEspacio.e8),
          child: Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Cargando categorías',
            ),
          ),
        ),
      ),
      error: (e, _) => enCaja(
        VistaError(
          key: const Key('categorias-error'),
          error: e,
          titulo: 'No pudimos cargar las categorías',
          alReintentar: () => ref.invalidate(categoriasProvider),
        ),
      ),
      data: (lista) => lista.isEmpty
          ? enCaja(
              const VistaEstado(
                key: Key('categorias-vacio'),
                icono: Icons.category_outlined,
                titulo: 'Todavía no hay categorías de servicio',
                mensaje: 'Cuando tu empresa las publique, aparecerán aquí.',
              ),
            )
          : SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: QpEspacio.pantalla,
              ),
              sliver: SliverToBoxAdapter(child: _Cuadricula(lista)),
            ),
    );
  }
}

/// Categorías en filas de 2 (o 3 en pantallas anchas). Cada fila toma el
/// alto de su tarjeta más alta, así el texto grande no se desborda (AC4-E7).
class _Cuadricula extends StatelessWidget {
  const _Cuadricula(this.lista);

  final List<Categoria> lista;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, restricciones) {
      final columnas = restricciones.maxWidth >= 520 ? 3 : 2;
      return Column(
        children: [
          for (var i = 0; i < lista.length; i += columnas)
            Padding(
              padding: const EdgeInsets.only(bottom: QpEspacio.e3),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var k = i; k < i + columnas; k++) ...[
                      if (k > i) const SizedBox(width: QpEspacio.e3),
                      Expanded(
                        child: k < lista.length
                            ? _TarjetaCategoria(lista[k])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _TarjetaCategoria extends StatelessWidget {
  const _TarjetaCategoria(this.categoria);

  final Categoria categoria;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Card(
      key: Key('categoria-${categoria.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Rutas.nuevaSolicitudEn(categoria.id)),
        child: Padding(
          padding: const EdgeInsets.all(QpEspacio.e4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: esquema.primaryContainer,
                  borderRadius: BorderRadius.circular(QpRadio.sm),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(QpEspacio.e2),
                  child: Icon(
                    iconoCategoria(categoria.nombre),
                    color: esquema.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: QpEspacio.e4),
              NombreCategoria(categoria.nombre),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaOpcion extends StatelessWidget {
  const _TarjetaOpcion(this.opcion);

  final OpcionInicio opcion;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: QpEspacio.e4,
        vertical: QpEspacio.e1,
      ),
      title: Text(opcion.titulo),
      subtitle: opcion.disponible
          ? null
          : Text('Próximamente · ${opcion.requisito}'),
      enabled: opcion.disponible,
      trailing: opcion.disponible
          ? const Icon(Icons.chevron_right_rounded)
          : null,
      onTap: !opcion.disponible
          ? null
          : opcion.esPestana
          ? () => context.go(opcion.ruta!)
          : () => context.push(opcion.ruta!),
    ),
  );
}

/// Nombre de una categoría en una tarjeta angosta. Los nombres de varias
/// palabras pasan a la siguiente línea; una sola palabra que no cabe
/// ("Electrodomésticos") se reduce en vez de partirse a la mitad.
class NombreCategoria extends StatelessWidget {
  const NombreCategoria(this.nombre, {super.key});

  final String nombre;

  @override
  Widget build(BuildContext context) {
    final texto = Text(nombre, style: Theme.of(context).textTheme.titleSmall);
    if (nombre.trim().contains(' ')) return texto;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: texto,
    );
  }
}
