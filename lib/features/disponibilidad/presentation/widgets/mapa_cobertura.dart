import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../domain/mapa_localidades.dart';

/// Mapa de Bogotá para elegir la cobertura tocando las localidades (SCRUM-89).
/// Solo dibuja los límites, sin mapa de fondo ni red (R5). Abre encuadrado en
/// la zona urbana; el botón alterna con la ciudad completa, que incluye
/// Sumapaz. Para lectores de pantalla el mapa se omite: los chips de la
/// página son la vía accesible y siempre están sincronizados con él.
class MapaCobertura extends StatefulWidget {
  const MapaCobertura({
    super.key,
    required this.mapa,
    required this.disponibles,
    required this.elegidas,
    required this.alTocar,
    this.habilitado = true,
    this.alto = 320,
  });

  final MapaLocalidades mapa;

  /// Códigos que vienen en `GET /v1/localities`: las demás se ven en gris y
  /// no se pueden tocar.
  final Set<String> disponibles;
  final Set<String> elegidas;
  final ValueChanged<String> alTocar;
  final bool habilitado;
  final double alto;

  @override
  State<MapaCobertura> createState() => _MapaCoberturaState();
}

class _MapaCoberturaState extends State<MapaCobertura> {
  final _control = TransformationController();
  bool _ciudadCompleta = false;
  Size? _vista;
  double? _anchoTrazos;
  Map<String, Path> _trazos = const {};

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  /// Escala de coordenadas proyectadas a puntos del lienzo, que tiene el ancho
  /// de la vista y la proporción de la ciudad.
  double _escala(double ancho) => ancho / widget.mapa.limites.width;

  Rect _enLienzo(Rect r, double k) => Rect.fromLTRB(
    (r.left - widget.mapa.limites.left) * k,
    (r.top - widget.mapa.limites.top) * k,
    (r.right - widget.mapa.limites.left) * k,
    (r.bottom - widget.mapa.limites.top) * k,
  );

  /// Transformación que centra [r] en la vista con un pequeño margen.
  Matrix4 _encuadre(Rect r, Size vista) {
    final lienzo = _enLienzo(r, _escala(vista.width));
    final s =
        0.94 *
        (vista.width / lienzo.width < vista.height / lienzo.height
            ? vista.width / lienzo.width
            : vista.height / lienzo.height);
    return Matrix4.identity()
      ..translateByDouble(
        vista.width / 2 - s * lienzo.center.dx,
        vista.height / 2 - s * lienzo.center.dy,
        0,
        1,
      )
      ..scaleByDouble(s, s, s, 1);
  }

  Rect get _objetivo =>
      _ciudadCompleta ? widget.mapa.limites : widget.mapa.limitesUrbanos;

  void _alternarEncuadre() {
    setState(() => _ciudadCompleta = !_ciudadCompleta);
    if (_vista != null) _control.value = _encuadre(_objetivo, _vista!);
  }

  Map<String, Path> _trazosPara(double ancho) {
    if (_anchoTrazos == ancho) return _trazos;
    final k = _escala(ancho);
    final origen = widget.mapa.limites.topLeft;
    _anchoTrazos = ancho;
    Path trazo(List<List<Offset>> anillos) {
      final path = Path()..fillType = PathFillType.evenOdd;
      for (final anillo in anillos) {
        path.addPolygon([for (final p in anillo) (p - origen) * k], true);
      }
      return path;
    }

    return _trazos = {
      for (final MapEntry(:key, :value) in widget.mapa.anillos.entries)
        key: trazo(value),
    };
  }

  void _tocar(TapUpDetails detalles, double ancho) {
    if (!widget.habilitado) return;
    final punto =
        detalles.localPosition / _escala(ancho) + widget.mapa.limites.topLeft;
    final codigo = widget.mapa.localidadEn(punto);
    if (codigo != null && widget.disponibles.contains(codigo)) {
      widget.alTocar(codigo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(QpRadio.lg),
      child: Container(
        height: widget.alto,
        decoration: BoxDecoration(
          color: esquema.surfaceContainerLow,
          border: Border.all(color: esquema.outlineVariant),
          borderRadius: BorderRadius.circular(QpRadio.lg),
        ),
        child: LayoutBuilder(
          builder: (context, restricciones) {
            final vista = restricciones.biggest;
            if (_vista == null) {
              // Primera vez: el visor aún no escucha al controlador.
              _control.value = _encuadre(_objetivo, vista);
            } else if (_vista != vista) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _control.value = _encuadre(_objetivo, vista);
              });
            }
            _vista = vista;
            final ancho = vista.width;
            final alto =
                ancho * widget.mapa.limites.height / widget.mapa.limites.width;
            return Stack(
              children: [
                // Para lectores de pantalla el lienzo se omite: los chips
                // son la vía accesible. El botón de encuadre sí se anuncia.
                ExcludeSemantics(
                  child: InteractiveViewer(
                    key: const Key('mapa-cobertura'),
                    transformationController: _control,
                    constrained: false,
                    boundaryMargin: EdgeInsets.all(ancho),
                    minScale: 0.9 * vista.height / alto,
                    maxScale: 12,
                    child: GestureDetector(
                      key: const Key('lienzo-mapa'),
                      onTapUp: (d) => _tocar(d, ancho),
                      child: CustomPaint(
                        size: Size(ancho, alto),
                        painter: _PintorMapa(
                          trazos: _trazosPara(ancho),
                          elegidas: {...widget.elegidas},
                          disponibles: {...widget.disponibles},
                          esquema: esquema,
                          control: _control,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: QpEspacio.e2,
                  right: QpEspacio.e2,
                  child: IconButton.filledTonal(
                    key: const Key('boton-encuadre-mapa'),
                    tooltip: _ciudadCompleta
                        ? 'Volver a la zona urbana'
                        : 'Ver toda la ciudad',
                    icon: Icon(
                      _ciudadCompleta ? Icons.zoom_in_map : Icons.zoom_out_map,
                    ),
                    onPressed: _alternarEncuadre,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PintorMapa extends CustomPainter {
  _PintorMapa({
    required this.trazos,
    required this.elegidas,
    required this.disponibles,
    required this.esquema,
    required this.control,
  }) : super(repaint: control);

  final Map<String, Path> trazos;
  final Set<String> elegidas;
  final Set<String> disponibles;
  final ColorScheme esquema;

  /// El borde se mantiene del mismo grosor en pantalla con cualquier zoom.
  final TransformationController control;

  @override
  void paint(Canvas canvas, Size size) {
    final escala = control.value.getMaxScaleOnAxis();
    final relleno = Paint()..style = PaintingStyle.fill;
    final borde = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    // Primero las no elegidas, para que el borde de las elegidas quede encima.
    final orden = [
      ...trazos.keys.where((c) => !elegidas.contains(c)),
      ...trazos.keys.where(elegidas.contains),
    ];
    for (final codigo in orden) {
      final trazo = trazos[codigo]!;
      final elegida = elegidas.contains(codigo);
      final disponible = disponibles.contains(codigo);
      relleno.color = !disponible
          ? esquema.onSurface.withValues(alpha: 0.08)
          : elegida
          ? esquema.primary.withValues(alpha: 0.55)
          : esquema.surface;
      borde
        ..color = elegida ? esquema.primary : esquema.outline
        ..strokeWidth = (elegida ? 2.0 : 1.0) / escala;
      canvas
        ..drawPath(trazo, relleno)
        ..drawPath(trazo, borde);
    }
  }

  @override
  bool shouldRepaint(_PintorMapa anterior) =>
      anterior.trazos != trazos ||
      anterior.esquema != esquema ||
      !setEquals(anterior.elegidas, elegidas) ||
      !setEquals(anterior.disponibles, disponibles);
}
