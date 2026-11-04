import 'package:flutter/material.dart';

/// Campo de contraseña con botón para mostrarla u ocultarla.
class CampoContrasena extends StatefulWidget {
  const CampoContrasena({
    required this.controlador,
    required this.etiqueta,
    this.validador,
    this.textoError,
    this.pistasAutocompletado = const [AutofillHints.password],
    this.accionTeclado,
    this.alEnviar,
    super.key,
  });

  final TextEditingController controlador;
  final String etiqueta;
  final FormFieldValidator<String>? validador;

  /// Error que devolvió el backend para este campo.
  final String? textoError;
  final Iterable<String> pistasAutocompletado;
  final TextInputAction? accionTeclado;
  final ValueChanged<String>? alEnviar;

  @override
  State<CampoContrasena> createState() => _CampoContrasenaState();
}

class _CampoContrasenaState extends State<CampoContrasena> {
  bool _oculta = true;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controlador,
    obscureText: _oculta,
    autofillHints: widget.pistasAutocompletado,
    textInputAction: widget.accionTeclado,
    onFieldSubmitted: widget.alEnviar,
    validator: widget.validador,
    decoration: InputDecoration(
      labelText: widget.etiqueta,
      errorText: widget.textoError,
      prefixIcon: const Icon(Icons.lock_outline_rounded),
      suffixIcon: IconButton(
        tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
        icon: Icon(
          _oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
        onPressed: () => setState(() => _oculta = !_oculta),
      ),
    ),
  );
}
