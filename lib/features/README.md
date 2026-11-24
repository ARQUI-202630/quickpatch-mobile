# features

Una carpeta por capacidad (por ejemplo `solicitudes/`), con tres capas:

- `data/`: modelos y cliente REST según `contracts/api-gateway/openapi/` (no se inventan endpoints ni campos).
- `domain/`: entidades y reglas de la capacidad, sin dependencias de Flutter ni de HTTP.
- `presentation/`: pantallas y widgets.

Una feature no importa a otra. Lo que usan varias va fuera de `features/`:

| Carpeta | Qué va ahí | Ejemplos |
|---|---|---|
| `core/` | Código sin pantallas que comparten varias features | `session/`, `network/`, `realtime/`, `catalogo/` (categorías del tenant), `notificaciones/` (contador del buzón), `geo/` (localidades y su mapa), `utils/` (validadores, fechas, montos), `solicitudes/` (estado de la solicitud, resumen de la calificación, su revisión y el contrato de las secciones del detalle), `equipo/` (puerto con los miembros del equipo del proveedor) |
| `shared/widgets/` | Widgets reutilizables | `MapaBogota`, `SelectorCategoria`, `iconoCategoria`, estados vacío, de error y de carga, `SeccionDetalle` (tarjeta con título de las secciones del detalle) |
| `app/` | Arranque, tema, rutas y el shell, que compone pantallas de varias features | `router/` (con `secciones_detalle_solicitud.dart`: el pago y la calificación en el detalle), `theme/`, `shell/` (barra inferior, Inicio y la pestaña del medio de cada rol), `composicion.dart` (conecta los puertos de `core/` con las features que los implementan) |

`core/` y `shared/` no importan de `features/`; `app/` sí, porque las compone. `shared/` puede usar `app/theme` (tokens y tema); ni `core/` ni `shared/` importan del resto de `app/`.

Cuando una feature necesita algo de otra (SCRUM-714):

- **Vocabulario común** (un enum, un dato del contrato que leen varias): va en `core/`, como `core/solicitudes/estado_solicitud.dart`.
- **Mostrar una pantalla o sección de otra feature:** la compone `app/`. El detalle de la solicitud recibe por parámetro las secciones de pago y calificación (`SeccionDetalleSolicitud`), que arma `app/router`.
- **Datos de otra feature:** un puerto en `core/` (un provider que lanza `UnimplementedError`) que `app/composicion.dart` conecta con la feature que lo implementa. Ejemplo: `miembrosEquipoProvider`, que usa «Mis pagos» y llena `equipo`.
- **Refrescar lo de otra feature:** `solicitudCambio(ref, id)` sube la revisión de la solicitud (`core/solicitudes/revision_solicitud.dart`), y los providers que dependen de ella la observan. Ninguna feature invalida providers de otra.

`test/arquitectura/capas_test.dart` verifica estas reglas en cada `flutter test`: ninguna feature importa otra, `core/` y `shared/` no importan de `features/` ni del resto de `app/`, y el `domain/` de una feature no importa Flutter, HTTP, Riverpod ni su `data/`.

| Feature | Qué hace |
|---|---|
| `autenticacion/` | Inicio de sesión, registro de cliente y de técnico o proveedor, activación con el enlace de invitación |
| `solicitudes/` | Nueva solicitud, detalle y seguimiento del cliente; servicios del técnico y su detalle |
| `disponibilidad/` | Disponibilidad y cobertura del técnico |
| `equipo/` | Equipo del proveedor e invitaciones |
| `notificaciones/` | Buzón de notificaciones del usuario |
| `empresa/` | Usuarios de la empresa cliente del `empresa_contacto` y alta de otros usuarios con invitación |
| `chat/` | Chat de la solicitud entre el cliente y el técnico asignado (se abre por ruta desde los detalles de `solicitudes/`) |
| `ofertas/` | Oferta pendiente del técnico: aceptar o rechazar con su cuenta regresiva |
| `cuenta/` | Pantalla de cuenta |
