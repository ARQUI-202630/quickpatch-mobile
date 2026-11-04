import 'package:flutter/material.dart';

/// Pide confirmación antes de salir de una pantalla con cambios sin guardar:
/// con la flecha de la barra y con el botón atrás del sistema (SCRUM-617).
///
/// Solo cubre `Navigator.maybePop`, que es lo que usan la flecha y el botón
/// atrás. Cuando la pantalla termina por sí sola (guardó y hace `context.pop`
/// o `context.go`), no pregunta nada.
class ConfirmarSalida extends StatelessWidget {
  const ConfirmarSalida({
    required this.hayCambios,
    required this.child,
    this.cambios,
    super.key,
  });

  /// Hay cambios mientras algún controlador tenga texto escrito.
  ConfirmarSalida.conTextos({
    required List<TextEditingController> controladores,
    required this.child,
    super.key,
  }) : hayCambios = (() => controladores.any((c) => c.text.trim().isNotEmpty)),
       cambios = Listenable.merge(controladores);

  /// Dice si hay algo que se perdería al salir. Se evalúa en cada cambio de
  /// [cambios] y cada vez que la pantalla se reconstruye.
  final bool Function() hayCambios;

  /// Lo que hay que escuchar para reevaluar [hayCambios] sin reconstruir la
  /// pantalla, por ejemplo los controladores de texto del formulario.
  final Listenable? cambios;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final escucha = cambios;
    if (escucha == null) return _construir(context);
    return ListenableBuilder(
      listenable: escucha,
      builder: (context, _) => _construir(context),
    );
  }

  Widget _construir(BuildContext context) => PopScope(
    canPop: !hayCambios(),
    onPopInvokedWithResult: (salio, _) async {
      if (salio) return;
      final navegador = Navigator.of(context);
      if (await _confirmar(context) && navegador.mounted) navegador.pop();
    },
    child: child,
  );

  static Future<bool> _confirmar(BuildContext context) async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        key: const Key('dialogo-confirmar-salida'),
        title: const Text('¿Salir sin guardar?'),
        content: const Text('Si sales ahora, se pierde lo que escribiste.'),
        actions: [
          TextButton(
            key: const Key('seguir-aqui'),
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Seguir aquí'),
          ),
          FilledButton(
            key: const Key('confirmar-salir'),
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    return salir ?? false;
  }
}
