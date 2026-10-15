import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/app/theme/app_theme.dart';
import 'package:quickpatch_mobile/app/theme/tokens.dart';
import 'package:quickpatch_mobile/core/errors/app_exception.dart';
import 'package:quickpatch_mobile/core/errors/codigo_error.dart';
import 'package:quickpatch_mobile/core/realtime/canal_tiempo_real.dart';
import 'package:quickpatch_mobile/features/solicitudes/data/repositorio_solicitudes.dart';
import 'package:quickpatch_mobile/features/solicitudes/domain/modelos.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/estado_vista.dart';
import 'package:quickpatch_mobile/features/solicitudes/presentation/paginas/detalle_solicitud_page.dart';

import '../../helpers/fakes.dart';

Solicitud _solicitud(EstadoSolicitud estado, {TecnicoAsignado? tecnico}) =>
    Solicitud(
      id: 's-1',
      estado: estado,
      categoriaId: 'c-1',
      descripcion: 'Fuga de agua debajo del lavaplatos',
      ubicacion: const Ubicacion(4.6533, -74.0836),
      direccion: 'Calle 45 # 13-20',
      creadaEn: DateTime.utc(2026, 10, 7, 15),
      tecnico: tecnico,
      asignadaEn: tecnico == null ? null : DateTime.utc(2026, 10, 7, 15, 20),
    );

const _carlos = TecnicoAsignado(id: 't-1', nombre: 'Carlos Ruiz');

void main() {
  late ConectorWsFalso conector;
  late int consultas;

  setUp(() {
    conector = ConectorWsFalso();
    consultas = 0;
  });

  Future<void> abrir(
    WidgetTester tester,
    Future<Solicitud> Function() obtener, {
    ThemeData? tema,
    Size tamano = const Size(1200, 4200),
  }) async {
    // Teléfono alto: toda la lista queda construida sin desplazar.
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          solicitudProvider.overrideWith((ref, id) {
            consultas++;
            return obtener();
          }),
          categoriasProvider.overrideWith(
            (ref) async => const [Categoria(id: 'c-1', nombre: 'Plomería')],
          ),
          canalTiempoRealProvider.overrideWith((ref) {
            final canal = CanalTiempoReal(
              url: Uri.parse('ws://localhost/api/v1/realtime'),
              obtenerToken: () => 'token-acceso',
              conectar: conector.call,
            );
            ref.onDispose(canal.cerrar);
            canal.iniciar();
            return canal;
          }),
        ],
        child: MaterialApp(
          theme: tema ?? AppTheme.claro(),
          home: const DetalleSolicitudPage(id: 's-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> conectar(WidgetTester tester) async {
    conector.ultima.recibir({'type': 'auth.accepted'});
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
    expect(find.textContaining('buscando un técnico'), findsOneWidget);
    expect(find.text('Calle 45 # 13-20'), findsOneWidget);
    expect(find.text('s-1'), findsOneWidget);
    expect(find.byKey(const Key('sin-tecnico')), findsOneWidget);
    expect(find.text('Aún no hay técnico asignado'), findsOneWidget);
  });

  testWidgets('la línea de tiempo marca hechos, el actual y pendientes', (
    tester,
  ) async {
    await abrir(
      tester,
      () async => _solicitud(EstadoSolicitud.enProgreso, tecnico: _carlos),
    );

    expect(find.byKey(const Key('linea-de-tiempo')), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp('Paso 1 de 4: Buscando técnico, completado'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Paso 2 de 4: Asignado, completado')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Paso 3 de 4: En progreso, en curso')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Paso 4 de 4: Completado, pendiente')),
      findsOneWidget,
    );
  });

  testWidgets('servicio terminado: todos los pasos completados', (
    tester,
  ) async {
    await abrir(
      tester,
      () async => _solicitud(EstadoSolicitud.pagado, tecnico: _carlos),
    );
    expect(
      find.bySemanticsLabel(RegExp('Paso 4 de 4: Completado, completado')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('en curso')), findsNothing);
  });

  testWidgets('cancelada: sin línea de tiempo ni tarjeta de técnico', (
    tester,
  ) async {
    await abrir(tester, () async => _solicitud(EstadoSolicitud.cancelado));
    expect(find.text('Cancelada'), findsOneWidget);
    expect(find.byKey(const Key('linea-de-tiempo')), findsNothing);
    expect(find.byKey(const Key('sin-tecnico')), findsNothing);
  });

  testWidgets('muestra el técnico con su especialidad y fecha', (tester) async {
    await abrir(
      tester,
      () async => _solicitud(EstadoSolicitud.asignado, tecnico: _carlos),
    );

    expect(find.byKey(const Key('tarjeta-tecnico')), findsOneWidget);
    expect(find.text('Carlos Ruiz'), findsOneWidget);
    expect(find.text('CR'), findsOneWidget);
    expect(find.textContaining('Plomería'), findsOneWidget);
    expect(find.textContaining('Desde '), findsOneWidget);
  });

  testWidgets('asignada sin datos del técnico no dice que falta técnico', (
    tester,
  ) async {
    await abrir(tester, () async => _solicitud(EstadoSolicitud.enProgreso));
    expect(find.byKey(const Key('tecnico-sin-datos')), findsOneWidget);
    expect(find.text('Aún no hay técnico asignado'), findsNothing);
  });

  testWidgets('técnico sin nombre en el contrato', (tester) async {
    await abrir(
      tester,
      () async => _solicitud(
        EstadoSolicitud.asignado,
        tecnico: const TecnicoAsignado(id: 't-1'),
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('tarjeta-tecnico')),
        matching: find.text('Técnico asignado'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('indica "En vivo" solo con el canal autenticado', (tester) async {
    await abrir(
      tester,
      () async => _solicitud(EstadoSolicitud.buscandoTecnico),
    );
    expect(find.text('Actualizando cada 30 s'), findsOneWidget);
    expect(
      jsonDecode(conector.ultima.enviadas.single),
      containsPair('type', 'auth'),
    );

    await conectar(tester);
    expect(find.text('En vivo'), findsOneWidget);

    await conector.ultima.cerrarDesdeServidor(1011);
    await tester.pumpAndSettle();
    expect(find.text('Actualizando cada 30 s'), findsOneWidget);
    // Deja que el reintento programado ocurra antes de terminar.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('un aviso de esta solicitud vuelve a consultar el detalle', (
    tester,
  ) async {
    var estado = EstadoSolicitud.buscandoTecnico;
    await abrir(tester, () async => _solicitud(estado, tecnico: null));
    await conectar(tester);
    final antes = consultas;

    // Aviso de otra solicitud: se ignora.
    conector.ultima.recibir({
      'type': 'service-request.status-changed',
      'serviceRequestId': 's-2',
      'status': 'asignado',
    });
    await tester.pumpAndSettle();
    expect(consultas, antes);

    estado = EstadoSolicitud.asignado;
    conector.ultima.recibir({
      'type': 'service-request.status-changed',
      'serviceRequestId': 's-1',
      'status': 'asignado',
    });
    await tester.pumpAndSettle();
    expect(consultas, antes + 1);
    expect(find.text('Técnico asignado'), findsOneWidget);
  });

  group('indicador de búsqueda de técnico (SCRUM-77)', () {
    Finder paso(String texto) => find.bySemanticsLabel(RegExp(texto));

    for (final (estado, explicacion) in [
      (EstadoSolicitud.buscandoTecnico, 'buscando un técnico disponible'),
      (EstadoSolicitud.enEspera, 'no hay técnicos disponibles'),
    ]) {
      testWidgets(
        '${estado.valor}: el primer paso sigue en curso y sin técnico',
        (tester) async {
          await abrir(tester, () async => _solicitud(estado));

          expect(
            find.descendant(
              of: find.byKey(const Key('estado-solicitud')),
              matching: find.text(estado.etiqueta),
              matchRoot: true,
            ),
            findsOneWidget,
          );
          expect(find.textContaining(explicacion), findsOneWidget);
          expect(
            paso('Paso 1 de 4: Buscando técnico, en curso'),
            findsOneWidget,
          );
          expect(paso('Paso 2 de 4: Asignado, pendiente'), findsOneWidget);
          expect(find.byKey(const Key('sin-tecnico')), findsOneWidget);
          expect(find.byKey(const Key('tarjeta-tecnico')), findsNothing);
        },
      );
    }

    testWidgets('asignado: el primer paso queda hecho y aparece el técnico', (
      tester,
    ) async {
      await abrir(
        tester,
        () async => _solicitud(EstadoSolicitud.asignado, tecnico: _carlos),
      );

      expect(paso('Paso 1 de 4: Buscando técnico, completado'), findsOneWidget);
      expect(paso('Paso 2 de 4: Asignado, en curso'), findsOneWidget);
      expect(find.byKey(const Key('tarjeta-tecnico')), findsOneWidget);
      expect(find.text('Carlos Ruiz'), findsOneWidget);
      expect(find.byKey(const Key('sin-tecnico')), findsNothing);
    });

    testWidgets('pasa de buscando a en espera y a asignado con cada aviso', (
      tester,
    ) async {
      var actual = _solicitud(EstadoSolicitud.buscandoTecnico);
      await abrir(tester, () async => actual);
      await conectar(tester);
      expect(find.textContaining('buscando un técnico'), findsOneWidget);

      Future<void> avisar(EstadoSolicitud estado) async {
        conector.ultima.recibir({
          'type': 'service-request.status-changed',
          'serviceRequestId': 's-1',
          'status': estado.valor,
        });
        await tester.pumpAndSettle();
      }

      actual = _solicitud(EstadoSolicitud.enEspera);
      await avisar(EstadoSolicitud.enEspera);
      expect(
        find.textContaining('no hay técnicos disponibles'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('sin-tecnico')), findsOneWidget);

      actual = _solicitud(EstadoSolicitud.asignado, tecnico: _carlos);
      await avisar(EstadoSolicitud.asignado);
      expect(find.text('Carlos Ruiz'), findsOneWidget);
      expect(find.textContaining('Plomería'), findsOneWidget);
      expect(paso('Paso 2 de 4: Asignado, en curso'), findsOneWidget);
    });
  });

  testWidgets('sin canal consulta cada 30 s; en vivo no', (tester) async {
    await abrir(
      tester,
      () async => _solicitud(EstadoSolicitud.buscandoTecnico),
    );
    final antes = consultas;

    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(consultas, antes + 1);

    await conectar(tester);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(consultas, antes + 1);
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

  testWidgets('tema oscuro y texto al 200 % sin desbordes', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await abrir(
      tester,
      () async => _solicitud(EstadoSolicitud.enProgreso, tecnico: _carlos),
      tema: AppTheme.oscuro(),
      tamano: const Size(1080, 2340),
    );
    await conectar(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('En vivo'), findsOneWidget);
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

  test('cada estado cae en un paso, salvo cancelado', () {
    expect(pasoDe(EstadoSolicitud.enEspera), 0);
    expect(pasoDe(EstadoSolicitud.cotizado), 1);
    expect(pasoDe(EstadoSolicitud.cotizacionAceptada), 1);
    expect(pasoDe(EstadoSolicitud.enProgreso), 2);
    expect(pasoDe(EstadoSolicitud.completado), 3);
    expect(pasoDe(EstadoSolicitud.cancelado), isNull);
  });

  test('el detalle lee el técnico de la versión 1.1.0', () {
    final s = Solicitud.desdeJson({
      'id': 's-1',
      'status': 'asignado',
      'categoryId': 'c-1',
      'technicianId': 't-1',
      'technician': {'id': 't-1', 'fullName': 'Carlos Ruiz'},
      'assignedAt': '2026-10-07T15:20:00Z',
      'description': 'Fuga',
      'location': {'latitude': 4.6, 'longitude': -74.0},
      'addressText': 'Calle 45',
      'createdAt': '2026-10-07T15:00:00Z',
    });
    expect(s.tecnico?.nombre, 'Carlos Ruiz');
    expect(s.asignadaEn, DateTime.utc(2026, 10, 7, 15, 20));
  });

  test('fechaCorta usa dd/mm/aaaa hh:mm', () {
    expect(fechaCorta(DateTime(2026, 3, 7, 9, 5)), '07/03/2026 09:05');
  });
}
