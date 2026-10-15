import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../core/catalogo/categoria.dart';
import 'icono_categoria.dart';

/// Elección de una categoría de Catalog con fichas de ícono y nombre, como
/// campo de formulario (valida y muestra el error debajo). Sirve para la
/// especialidad del técnico (SCRUM-22) y para filtrar ofertas.
class SelectorCategoria extends FormField<String> {
  SelectorCategoria({
    required List<Categoria> categorias,
    required ValueChanged<String> alElegir,
    String? inicial,
    String mensajeObligatorio = 'Elige una categoría.',
    super.key,
  }) : super(
         initialValue: categorias.any((c) => c.id == inicial) ? inicial : null,
         validator: (valor) => valor == null ? mensajeObligatorio : null,
         builder: (campo) {
           final esquema = Theme.of(campo.context).colorScheme;
           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Wrap(
                 spacing: QpEspacio.e2,
                 runSpacing: QpEspacio.e2,
                 children: [
                   for (final categoria in categorias)
                     ChoiceChip(
                       key: Key('categoria-${categoria.id}'),
                       avatar: Icon(iconoCategoria(categoria.nombre)),
                       label: Text(categoria.nombre),
                       selected: campo.value == categoria.id,
                       showCheckmark: false,
                       onSelected: (_) {
                         campo.didChange(categoria.id);
                         alElegir(categoria.id);
                       },
                     ),
                 ],
               ),
               if (campo.hasError)
                 Padding(
                   padding: const EdgeInsets.only(
                     top: QpEspacio.e2,
                     left: QpEspacio.e4,
                   ),
                   child: Text(
                     campo.errorText!,
                     style: Theme.of(campo.context).textTheme.bodySmall
                         ?.copyWith(color: esquema.error),
                   ),
                 ),
             ],
           );
         },
       );
}
