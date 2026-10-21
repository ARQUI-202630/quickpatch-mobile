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

Las opciones del inicio dependen del rol del usuario (`app/shell/opciones_por_rol.dart`, SCRUM-25).

## Capacidades

|Capacidad|Contrato|Historia|
|---|---|---|
|Registro de cliente y técnico, inicio de sesión y perfil|`identity.v1.yaml`|SCRUM-63|
|Nueva solicitud: categoría, descripción, dirección y ubicación del GPS; sin GPS, la app ubica la dirección y pregunta «¿Es aquí?» con la localidad y el mapa antes de crearla; confirmación con el estado|`catalog.v1.yaml` (`GET /v1/catalog/categories`), `service-request.v1.yaml` 1.3.0 (`POST /v1/service-requests`, `POST /v1/service-requests/location-preview`, `GET /v1/service-requests/{id}`)|SCRUM-27 / SCRUM-71 / SCRUM-457|
|Seguimiento de la solicitud: línea de estado en 4 pasos, técnico asignado (nombre y especialidad, que es la categoría por RN-M9) y avisos en tiempo real, con consulta cada 30 s si el canal no está disponible|`service-request.v1.yaml` 1.1.0 (`GET /v1/service-requests/{id}`), `asyncapi/realtime.v1.yaml` (`/v1/realtime`, ADR-023)|SCRUM-31 / SCRUM-83|
|Cancelar la solicitud antes de que inicie el servicio, con el motivo (de 5 a 500 caracteres); si ya inició, lo explica y recarga el estado. Una solicitud cancelada muestra la fecha y el motivo|`service-request.v1.yaml` 1.5.0 (`POST /v1/service-requests/{id}/cancel`, `GET /v1/service-requests/{id}`)|SCRUM-472 / SCRUM-477|
|Cotización: el técnico asignado envía mano de obra y materiales (pesos enteros) con el total visible antes de enviar, hasta 3 por solicitud; el cliente ve el desglose y la hora límite, la acepta tras confirmar el total o la rechaza con un motivo opcional (rechazar la tercera cancela la solicitud). Un 409 se explica y recarga el estado|`service-request.v1.yaml` 1.6.0 (`GET` y `POST /v1/service-requests/{id}/quotes`, `POST .../quotes/{quoteId}/accept` y `.../reject`)|SCRUM-486 / SCRUM-489|
|Ejecución del servicio: con la cotización aceptada el técnico inicia (tras confirmar), toma o elige fotos del trabajo y las sube con progreso (hasta 10, reducidas a 2560 px; más de 10 MB se rechaza antes de enviar) y completa solo con al menos una foto; el cliente ve las fotos desde que inicia y las abre completas con zoom. Las fotos se descargan con la sesión. Un 409 se explica y recarga; un 422 pide la foto|`service-request.v1.yaml` 1.7.0 (`POST .../start`, `POST` y `GET .../evidence`, `GET .../evidence/{evidenceId}/file`, `POST .../complete`)|SCRUM-35 / SCRUM-95|
|Servicios del técnico: lista de sus servicios asignados con filtro por estado y paginación, y detalle con cliente, dirección y mapa de solo lectura; aviso «Te asignaron un servicio»|`service-request.v1.yaml` 1.2.0 (`GET /v1/technicians/me/service-requests`, `GET /v1/service-requests/{id}`), `asyncapi/realtime.v1.yaml`|SCRUM-34 / SCRUM-92 / SCRUM-467|
|Ofertas del técnico: la oferta pendiente arriba de Servicios con localidad, distancia y cuenta regresiva, sin la dirección; aceptar o rechazar, y aviso «Tienes una oferta nueva»|`matching.v1.yaml` 1.0.0 (`GET /v1/matching/offers`, `POST .../accept` y `.../reject`), `asyncapi/realtime.v1.yaml` (`offer.created`)|SCRUM-30 / SCRUM-80|
|Buzón de notificaciones: campana con las sin leer en el inicio y fila en Cuenta; lista con las no leídas marcadas, y al tocar una se marca leída y abre su pantalla; se actualiza con el canal en tiempo real (el proveedor no tiene buzón)|`communication.v1.yaml` 1.2.0 (`GET /v1/notifications`, `POST /v1/notifications/{id}/read`)|SCRUM-459|
|Disponibilidad y cobertura del técnico: interruptor de disponibilidad y localidades elegidas en un mapa de Bogotá o con chips|`matching.v1.yaml` (`/v1/technicians/me/availability`, `/v1/technicians/me/coverage`, `/v1/localities`)|SCRUM-89|
|Equipo del proveedor: técnicos con filtro y paginación, alta con enlace de invitación para compartir y enlace nuevo|`identity.v1.yaml` 1.7.0 (`/v1/providers/me/technicians`)|SCRUM-36 / SCRUM-98|

## Sistema de diseño (SCRUM-439)

Tema azul con la paleta del panel web en `lib/app/theme/` (`tokens.dart` y `app_theme.dart`). Las pantallas leen `Theme.of(context)` y `context.estados`, nunca colores sueltos. Barra inferior por rol en `lib/app/shell/`.

Componentes para reutilizar en las pantallas del técnico (SCRUM-22, 30, 33 y 34):

|Componente|Archivo|Uso|
|---|---|---|
|`TarjetaSolicitud` (y `.de(solicitud)`)|`features/solicitudes/presentation/widgets/`|Resumen en listas, con acciones al pie (aceptar o rechazar una oferta)|
|`ChipEstado`|`features/solicitudes/presentation/widgets/`|Estado de la solicitud con su tono (`estado_vista.dart`)|
|`SelectorCategoria`|`features/solicitudes/presentation/widgets/`|Campo de formulario para elegir una categoría de Catalog (especialidad)|
|`BotonPrincipal`, `BotonSecundario`, `BotonPeligro`|`shared/widgets/`|Acción principal con carga, secundaria y de rechazo|
|`VistaEstado`, `VistaError`, `IndicadorCarga`|`shared/widgets/`|Estados vacío, de error con reintento y de carga|
|`MensajeError`, `CampoContrasena`|`shared/widgets/`|Error de formulario y contraseña visible a demanda|

Todos cumplen WCAG AA y no se desbordan con el texto al 200 % (AC4-E7); hay pruebas para cada uno.

## Conexión con QA

Un teléfono no puede editar su archivo `hosts` ni confiar en el certificado autofirmado del laboratorio (R9). Por eso `config/qa.json`:

- apunta a la IP de VM1 (`API_BASE_URL`) y envía `Host: qa.quickpatch.internal` (`HOST_HEADER`), para que el Nginx de VM1 elija QA;
- fija el certificado de VM1 por su huella SHA-256 (`CERT_SHA256`): la app solo confía en ese certificado. DevOps obtiene la huella desde la red del laboratorio con
  `openssl s_client -connect 10.43.100.168:443 </dev/null | openssl x509 -noout -fingerprint -sha256`
  y la escribe en `config/qa.json` antes de compilar el APK de QA. El valor no es secreto (es público en el propio certificado).
  **Si VM1 regenera su certificado, hay que actualizar la huella**: con la anterior la app rechaza la conexión (`HandshakeException`). Pasó el 16 de octubre de 2026 (SCRUM-448).

El teléfono o el emulador deben estar conectados a la VPN de la universidad.

**Prueba de humo contra QA (SCRUM-448):** `integration_test/humo_qa_test.dart` corre la app real en un emulador o teléfono con la configuración de QA. Un cliente nuevo inicia sesión, crea una solicitud sin GPS (la app ubica la dirección y pregunta «¿Es aquí?») y la cancela; cada paso imprime su tiempo. Con el emulador encendido:

```bash
flutter test integration_test/humo_qa_test.dart --dart-define-from-file=config/qa.json
```

**APK de QA (SCRUM-447):** cada push a `release/*` compila el APK con `config/qa.json` y lo deja como artefacto `apk-qa` del workflow (pestaña Actions, 30 días). En local: `flutter build apk --release --dart-define-from-file=config/qa.json`.

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
