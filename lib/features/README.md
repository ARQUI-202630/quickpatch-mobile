# features

Una carpeta por capacidad (por ejemplo `service_requests/`), con tres capas:

- `data/`: modelos y cliente REST según `contracts/openapi/` (no se inventan endpoints ni campos).
- `domain/`: entidades y reglas de la capacidad, sin dependencias de Flutter ni de HTTP.
- `presentation/`: pantallas y widgets.

Una feature no importa a otra; lo compartido va en `core/`.
