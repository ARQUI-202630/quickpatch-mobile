import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/app/theme/tokens.dart';
import 'package:quickpatch_mobile/core/catalogo/categoria.dart';
import 'package:quickpatch_mobile/features/solicitudes/domain/modelos.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/widgets/chip_estado.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/widgets/tarjeta_solicitud.dart';
import 'package:quickpatch_mobile/shared/widgets/botones.dart';
import 'package:quickpatch_mobile/shared/widgets/selector_categoria.dart';

Widget _conTema(Widget hijo, {double escalaTexto = 1}) => MaterialApp(
  theme: AppTheme.claro(),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(escalaTexto)),
    child: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: hijo,
      ),
    ),
  ),
);

final _solicitud = Solicitud(
  id: 's-1',
  estado: EstadoSolicitud.asignado,
  categoriaId: 'c-1',
  descripcion: 'Fuga de agua debajo del lavaplatos',
  ubicacion: const Ubicacion(4.6533, -74.0836),
  direccion: 'Calle 45 # 13-20',
  creadaEn: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
);

const _categorias = [
  Categoria(id: 'c-1', nombre: 'Plomería'),
  Categoria(id: 'c-2', nombre: 'Eléctrico'),
];

void main() {
  group('ChipEstado', () {
    testWidgets('muestra la etiqueta en el tono del estado', (tester) async {
      await tester.pumpWidget(
        _conTema(const ChipEstado(EstadoSolicitud.cancelado)),
      );
      final texto = tester.widget<Text>(find.text('Cancelada'));
      expect(texto.style?.color, QpEstados.claro.peligro);
      expect(find.bySemanticsLabel('Estado: Cancelada'), findsOneWidget);
    });

    testWidgets('cada estado se dibuja sin errores', (tester) async {
      await tester.pumpWidget(
        _conTema(
          Wrap(
            children: [
              for (final estado in EstadoSolicitud.values) ChipEstado(estado),
            ],
          ),
        ),
      );
      for (final estado in EstadoSolicitud.values) {
        expect(find.text(estado.etiqueta), findsOneWidget);
      }
    });
  });

  group('TarjetaSolicitud', () {
    testWidgets('resume la solicitud y responde al toque', (tester) async {
      var toques = 0;
      await tester.pumpWidget(
        _conTema(
          TarjetaSolicitud.de(
            _solicitud,
            servicio: 'Plomería',
            alTocar: () => toques++,
          ),
        ),
      );
      expect(find.text('Plomería'), findsOneWidget);
      expect(find.byType(ChipEstado), findsOneWidget);
      expect(find.text('Calle 45 # 13-20'), findsOneWidget);
      expect(find.text('Hace 5 min'), findsOneWidget);
      expect(find.byIcon(Icons.plumbing_outlined), findsOneWidget);

      await tester.tap(find.text('Fuga de agua debajo del lavaplatos'));
      expect(toques, 1);
    });

    testWidgets('sin servicio usa un título genérico y no exige estado', (
      tester,
    ) async {
      await tester.pumpWidget(
        _conTema(
          const TarjetaSolicitud(
            servicio: 'Oferta de servicio',
            descripcion: 'Revisar breaker',
            direccion: 'Carrera 7 # 40-62',
          ),
        ),
      );
      expect(find.byType(ChipEstado), findsNothing);
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
      expect(
        find.text('Solicitud de servicio'),
        findsNothing,
        reason: 'el título genérico solo aplica a TarjetaSolicitud.de',
      );
    });

    testWidgets('muestra las acciones (aceptar o rechazar una oferta)', (
      tester,
    ) async {
      var aceptadas = 0;
      var rechazadas = 0;
      await tester.pumpWidget(
        _conTema(
          TarjetaSolicitud.de(
            _solicitud,
            acciones: [
              BotonPeligro(
                texto: 'Rechazar',
                icono: Icons.close_rounded,
                alPresionar: () => rechazadas++,
              ),
              BotonSecundario(
                texto: 'Aceptar',
                icono: Icons.check_rounded,
                alPresionar: () => aceptadas++,
              ),
            ],
          ),
        ),
      );
      expect(find.text('Solicitud de servicio'), findsOneWidget);
      await tester.tap(find.text('Aceptar'));
      await tester.tap(find.text('Rechazar'));
      expect((aceptadas, rechazadas), (1, 1));
    });

    testWidgets('con texto al 200 % no se desborda (AC4-E7)', (tester) async {
      await tester.pumpWidget(
        _conTema(
          TarjetaSolicitud.de(
            _solicitud,
            servicio: 'Aire acondicionado',
            acciones: [
              BotonPeligro(texto: 'Rechazar', alPresionar: () {}),
              BotonSecundario(texto: 'Aceptar', alPresionar: () {}),
            ],
          ),
          escalaTexto: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    test('fechaRelativa', () {
      final ahora = DateTime(2026, 10, 12, 12);
      expect(fechaRelativa(ahora, ahora), 'Hace un momento');
      expect(
        fechaRelativa(ahora.subtract(const Duration(minutes: 30)), ahora),
        'Hace 30 min',
      );
      expect(
        fechaRelativa(ahora.subtract(const Duration(hours: 3)), ahora),
        'Hace 3 h',
      );
      expect(
        fechaRelativa(ahora.subtract(const Duration(days: 1)), ahora),
        'Ayer',
      );
      expect(fechaRelativa(DateTime(2026, 3, 7), ahora), '07/03/2026');
    });
  });

  group('SelectorCategoria', () {
    testWidgets('exige una categoría y avisa al elegir', (tester) async {
      final formulario = GlobalKey<FormState>();
      String? elegida;
      await tester.pumpWidget(
        _conTema(
          Form(
            key: formulario,
            child: SelectorCategoria(
              categorias: _categorias,
              mensajeObligatorio: 'Elige tu especialidad.',
              alElegir: (id) => elegida = id,
            ),
          ),
        ),
      );

      expect(formulario.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Elige tu especialidad.'), findsOneWidget);

      await tester.tap(find.text('Eléctrico'));
      await tester.pump();
      expect(elegida, 'c-2');
      expect(formulario.currentState!.validate(), isTrue);
      await tester.pump();
      expect(find.text('Elige tu especialidad.'), findsNothing);
      final chip = tester.widget<ChoiceChip>(
        find.byKey(const Key('categoria-c-2')),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets('ignora una categoría inicial que ya no existe', (
      tester,
    ) async {
      final formulario = GlobalKey<FormState>();
      await tester.pumpWidget(
        _conTema(
          Form(
            key: formulario,
            child: SelectorCategoria(
              categorias: _categorias,
              inicial: 'c-borrada',
              alElegir: (_) {},
            ),
          ),
        ),
      );
      expect(formulario.currentState!.validate(), isFalse);
    });

    testWidgets('respeta la categoría inicial válida', (tester) async {
      await tester.pumpWidget(
        _conTema(
          Form(
            child: SelectorCategoria(
              categorias: _categorias,
              inicial: 'c-1',
              alElegir: (_) {},
            ),
          ),
        ),
      );
      final chip = tester.widget<ChoiceChip>(
        find.byKey(const Key('categoria-c-1')),
      );
      expect(chip.selected, isTrue);
    });
  });
}
