# features

Una carpeta por capacidad (por ejemplo `solicitudes/`), con tres capas:

- `data/`: modelos y cliente REST según `contracts/api-gateway/openapi/` (no se inventan endpoints ni campos).
- `domain/`: entidades y reglas de la capacidad, sin dependencias de Flutter ni de HTTP.
- `presentation/`: pantallas y widgets.

Una feature no importa a otra. Lo que usan varias va fuera de `features/`:

| Carpeta | Qué va ahí | Ejemplos |
|---|---|---|
| `core/` | Código sin pantallas que comparten varias features | `session/`, `network/`, `realtime/`, `catalogo/` (categorías del tenant), `geo/` (localidades y su mapa), `utils/` (validadores, fechas, montos) |
| `shared/widgets/` | Widgets reutilizables | `MapaBogota`, `SelectorCategoria`, `iconoCategoria`, estados vacío, de error y de carga |
| `app/` | Arranque, tema, rutas y el shell, que compone pantallas de varias features | `router/`, `theme/`, `shell/` (barra inferior, Inicio y la pestaña del medio de cada rol) |

`core/` y `shared/` no importan de `features/`; `app/` sí, porque las compone.

| Feature | Qué hace |
|---|---|
| `autenticacion/` | Inicio de sesión, registro de cliente y de técnico o proveedor, activación con el enlace de invitación |
| `solicitudes/` | Nueva solicitud, detalle y seguimiento del cliente; servicios del técnico y su detalle |
| `disponibilidad/` | Disponibilidad y cobertura del técnico |
| `equipo/` | Equipo del proveedor e invitaciones |
| `inicio/` | Pantalla de cuenta |
