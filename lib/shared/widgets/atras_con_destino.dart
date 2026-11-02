import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Hace que atrás vuelva a la pantalla anterior y, si la pantalla se abrió sin
/// pila (con `context.go` o desde un enlace), lleve a [destino] en vez de
/// cerrar la app (SCRUM-617).
///
/// Sirve para la flecha de la barra y para el botón atrás del sistema. Con
/// pila no cambia nada: la pantalla se cierra como siempre.
class AtrasConDestino extends StatelessWidget {
  const AtrasConDestino({
    required this.destino,
    required this.child,
    super.key,
  });

  final String destino;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Sin router (una pantalla montada sola) atrás se comporta como siempre.
    final router = GoRouter.maybeOf(context);
    return PopScope(
      canPop: router?.canPop() ?? true,
      onPopInvokedWithResult: (salio, _) {
        if (!salio) router?.go(destino);
      },
      child: child,
    );
  }
}
