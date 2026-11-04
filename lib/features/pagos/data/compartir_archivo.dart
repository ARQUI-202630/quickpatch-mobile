import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Abre el menú nativo para guardar o enviar un archivo (Drive, correo,
/// WhatsApp…), sin escribirlo antes en el almacenamiento de la app.
typedef CompartirArchivo = Future<void> Function({
  required Uint8List bytes,
  required String nombre,
  required String tipo,
});

/// Se inyecta para que las pruebas no dependan del sistema operativo.
final compartirArchivoProvider = Provider<CompartirArchivo>(
  (ref) =>
      ({
        required Uint8List bytes,
        required String nombre,
        required String tipo,
      }) async {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile.fromData(bytes, mimeType: tipo, name: nombre)],
            fileNameOverrides: [nombre],
            subject: nombre,
          ),
        );
      },
);
