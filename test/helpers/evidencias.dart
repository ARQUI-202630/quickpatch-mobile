import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:quickpatch_mobile/features/solicitudes/data/selector_fotos.dart';

/// `Evidence` según `service-request.v1.yaml` 1.7.0.
Map<String, dynamic> evidenciaJson({
  String id = 'e-1',
  String subida = '2026-10-20T16:40:00Z',
}) => {'id': id, 'uploadedAt': subida};

/// PNG de 1 × 1 px, válido para `Image.memory`.
final pngMinimo = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0, //
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, //
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Respuesta binaria de `GET .../evidence/{evidenceId}/file`.
ResponseBody respuestaImagen([Uint8List? bytes]) => ResponseBody.fromBytes(
  bytes ?? pngMinimo,
  200,
  headers: {
    Headers.contentTypeHeader: ['image/png'],
  },
);

/// Selector de fotos en memoria: entrega [foto] (o nada) y guarda el origen.
class SelectorFotosFalso implements SelectorFotos {
  SelectorFotosFalso([this.foto]);

  FotoElegida? foto;
  final origenes = <OrigenFoto>[];

  @override
  Future<FotoElegida?> elegir(OrigenFoto origen) async {
    origenes.add(origen);
    return foto;
  }
}
