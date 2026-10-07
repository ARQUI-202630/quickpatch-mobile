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
  features/<capacidad>/     data/, domain/ y presentation/ (autenticacion, inicio, solicitudes)
test/                       Misma estructura que lib/
config/                     dev.json y qa.json (sin secretos: quedan dentro del APK)
```

Las opciones del inicio dependen del rol del usuario (`features/inicio/domain/opciones_por_rol.dart`, SCRUM-25).

## Capacidades

|Capacidad|Contrato|Historia|
|---|---|---|
|Registro de cliente y técnico, inicio de sesión y perfil|`identity.v1.yaml`|SCRUM-63|
|Nueva solicitud: categoría, descripción, dirección y ubicación del GPS; confirmación con el estado|`catalog.v1.yaml` (`GET /v1/catalog/categories`), `service-request.v1.yaml` (`POST` y `GET /v1/service-requests`)|SCRUM-27 / SCRUM-71|

## Conexión con QA

Un teléfono no puede editar su archivo `hosts` ni confiar en el certificado autofirmado del laboratorio (R9). Por eso `config/qa.json`:

- apunta a la IP de VM1 (`API_BASE_URL`) y envía `Host: qa.quickpatch.internal` (`HOST_HEADER`), para que el Nginx de VM1 elija QA;
- fija el certificado de VM1 por su huella SHA-256 (`CERT_SHA256`): la app solo confía en ese certificado. DevOps obtiene la huella desde la red del laboratorio con
  `openssl s_client -connect 10.43.100.168:443 </dev/null | openssl x509 -noout -fingerprint -sha256`
  y la escribe en `config/qa.json` antes de compilar el APK de QA. El valor no es secreto (es público en el propio certificado).

El teléfono o el emulador deben estar conectados a la VPN de la universidad.

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
