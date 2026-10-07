# QUICKPATCH Mobile

**Tecnología:** Flutter 3.47.5 + Dart 3.13.4 (`.flutter-version`).

**Usuarios principales:** clientes y técnicos.

La aplicación móvil concentra los flujos de solicitud, matching/asignación visible al usuario, ejecución, evidencia, pago/calificación y demás capacidades móviles definidas por requisitos.

Consume únicamente contratos REST publicados en `contracts/api-gateway/openapi/` (submódulo `quickpatch-api-gateway`).

## Estructura

```text
lib/
  main.dart                 Punto de entrada (ProviderScope de Riverpod)
  app/                      App, rutas (go_router) y tema
  core/
    config/                 Entorno (--dart-define-from-file=config/<entorno>.json)
    network/                Cliente HTTP (dio), interceptores (JWT, X-Channel-Id, X-Correlation-Id) y rutas del contrato
    errors/                 Problem Details (RFC 9457) → mensajes para el usuario
    session/                Sesión y rol, guardados en almacenamiento seguro
    realtime/, utils/       Mensajes en tiempo real y utilidades (montos)
  features/<capacidad>/     data/, domain/ y presentation/ (autenticacion, inicio)
test/                       Misma estructura que lib/
config/                     dev.json y qa.json (sin secretos: quedan dentro del APK)
```

Las opciones del inicio dependen del rol del usuario (`features/inicio/domain/opciones_por_rol.dart`, SCRUM-25).

## Comandos

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test   # formato, igual que el CI
flutter analyze
flutter test --coverage                                     # el CI exige ≥ 80% de líneas
flutter run --dart-define-from-file=config/dev.json   # backend local en 10.0.2.2:8080
flutter build apk --release
```

## Pendiente

- Registro de empresa (`POST /v1/auth/register/company`), refresh tokens y rutas marcadas "pendiente de contrato" en `api_endpoints.dart`: dependen del DD 3.1.
- QA usa TLS con certificado autofirmado (restricción R9): para que el APK confíe en `qa.quickpatch.internal` hace falta agregar el certificado del laboratorio en un `network_security_config`.
