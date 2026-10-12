import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/app/theme/tokens.dart';
import 'package:quickpatch_mobile/core/errors/app_exception.dart';
import 'package:quickpatch_mobile/core/errors/codigo_error.dart';
import 'package:quickpatch_mobile/features/solicitudes/data/repositorio_solicitudes.dart';
import 'package:quickpatch_mobile/features/solicitudes/domain/modelos.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/estado_vista.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/paginas/detalle_solicitud_page.dart';

Solicitud _solicitud(EstadoSolicitud estado) => Solicitud(
  id: 's-1',
  estado: estado,
  categoriaId: 'c-1',
  descripcion: 'Fuga de agua debajo del lavaplatos',
  ubicacion: const Ubicacion(4.6533, -74.0836),
  direccion: 'Calle 45 # 13-20',
  creadaEn: DateTime.utc(2026, 10, 7, 15),
);

void main() {
  Future<void> abrir(
    WidgetTester tester,
    Future<Solicitud> Function() obtener,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [solicitudProvider.overrideWith((ref, id) => obtener())],
        child: MaterialApp(
          theme: AppTheme.claro(),
          home: const DetalleSolicitudPage(id: 's-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra el estado con su explicación y los datos', (
    tester,
  ) async {
    await abrir(
      tester,
      () async => _solicitud(EstadoSolicitud.buscandoTecnico),
    );

    expect(find.byKey(const Key('estado-solicitud')), findsOneWidget);
    expect(find.text('Buscando técnico'), findsOneWidget);
    expect(find.textContaining('buscando un técnico'), findsOneWidget);
    expect(find.text('Calle 45 # 13-20'), findsOneWidget);
    expect(find.text('s-1'), findsOneWidget);
  });

  testWidgets('si falla muestra el error y reintenta', (tester) async {
    // Falla hasta que la persona toca "Reintentar" (Riverpod también
    // reintenta solo, así que el fallo no puede depender del número de
    // intentos).
    var conectado = false;
    await abrir(tester, () async {
      if (!conectado) throw const AppException(CodigoError.sinConexion);
      return _solicitud(EstadoSolicitud.asignado);
    });

    expect(find.byKey(const Key('detalle-error')), findsOneWidget);
    expect(
      find.text(const AppException(CodigoError.sinConexion).mensaje),
      findsOneWidget,
    );
    conectado = true;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Técnico asignado'), findsOneWidget);
  });

  test('cada estado tiene ícono, tono y descripción', () {
    for (final estado in EstadoSolicitud.values) {
      final vista = vistaDe(estado);
      expect(vista.descripcion, isNotEmpty);
      final (color, fondo) = vista.colores(QpEstados.claro);
      expect(color, isNot(fondo));
    }
    expect(vistaDe(EstadoSolicitud.cancelado).tono, TonoEstado.peligro);
    expect(vistaDe(EstadoSolicitud.enEspera).tono, TonoEstado.aviso);
    expect(vistaDe(EstadoSolicitud.pagado).tono, TonoEstado.exito);
    expect(vistaDe(EstadoSolicitud.enProgreso).tono, TonoEstado.info);
  });

  test('fechaCorta usa dd/mm/aaaa hh:mm', () {
    expect(fechaCorta(DateTime(2026, 3, 7, 9, 5)), '07/03/2026 09:05');
  });
}
