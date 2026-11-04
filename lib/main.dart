import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/network/politica_reintento.dart';

void main() {
  // La OFL pide acompañar la fuente con su licencia (pantalla de licencias).
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Plus Jakarta Sans'], ofl);
  });
  // Sin reintentos de los 4xx: con ellos la pantalla se queda cargando.
  runApp(const ProviderScope(retry: politicaReintento, child: QuickpatchApp()));
}
