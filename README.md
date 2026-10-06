# QUICKPATCH Mobile

**Tecnología:** Flutter 3.47.5 + Dart 3.13.4 (`.flutter-version`).

**Usuarios principales:** clientes y técnicos.

La aplicación móvil concentra los flujos de solicitud, matching/asignación visible al usuario, ejecución, evidencia, pago/calificación y demás capacidades móviles definidas por requisitos.

Consume únicamente contratos REST publicados en `contracts/openapi/` (submódulo `quickpatch-contracts`).

## Estructura

```text
lib/
  main.dart     Punto de entrada
  app.dart      Raíz de la app (tema y navegación)
  core/         Configuración por ambiente, cliente HTTP (JWT, X-Correlation-Id), errores RFC 9457
  features/     Una carpeta por capacidad, con data/, domain/ y presentation/
test/           Misma estructura que lib/
android/        Proyecto Android (la app se distribuye como APK)
```

## Comandos

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test   # formato, igual que el CI
flutter analyze
flutter test --coverage                                     # el CI exige ≥ 80% de líneas
flutter run
flutter build apk --release
```
