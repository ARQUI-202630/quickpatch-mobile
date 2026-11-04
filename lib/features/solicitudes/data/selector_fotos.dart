import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// De dónde sale la foto de evidencia.
enum OrigenFoto { camara, galeria }

/// Foto elegida por el técnico, lista para subir.
class FotoElegida {
  const FotoElegida(this.bytes, this.nombre);

  final Uint8List bytes;
  final String nombre;
}

/// Toma o elige una foto. Las pruebas lo reemplazan con fotos en memoria.
abstract interface class SelectorFotos {
  /// `null` si el técnico vuelve sin elegir.
  Future<FotoElegida?> elegir(OrigenFoto origen);
}

/// Cámara o galería del sistema con `image_picker`. La foto se reduce a 2560
/// px y calidad 85: una foto de trabajo se ve bien y queda muy por debajo de
/// los 10 MB del contrato. En Android 13 o más, la galería usa el selector de
/// fotos del sistema y no pide permisos.
class SelectorFotosSistema implements SelectorFotos {
  SelectorFotosSistema([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<FotoElegida?> elegir(OrigenFoto origen) async {
    final archivo = await _picker.pickImage(
      source: origen == OrigenFoto.camara
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 2560,
      maxHeight: 2560,
      imageQuality: 85,
    );
    if (archivo == null) return null;
    return FotoElegida(await archivo.readAsBytes(), archivo.name);
  }
}

final selectorFotosProvider = Provider<SelectorFotos>(
  (ref) => SelectorFotosSistema(),
);
