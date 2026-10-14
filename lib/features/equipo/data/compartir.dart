import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Abre el menú nativo para compartir [texto] (WhatsApp, correo, SMS…).
typedef Compartir = Future<void> Function({
  required String texto,
  String? asunto,
});

/// Se inyecta para que las pruebas no dependan del sistema operativo.
final compartirProvider = Provider<Compartir>(
  (ref) => ({required String texto, String? asunto}) async {
    await SharePlus.instance.share(ShareParams(text: texto, subject: asunto));
  },
);
