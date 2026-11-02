# Navegación de la app: inventario de pantallas y regla de la flecha

Inventario de la SCRUM-616 (historia SCRUM-615). La SCRUM-617 (#44) aplicó la regla y la SCRUM-618 la prueba: las tablas dicen cómo se comporta hoy cada pantalla, que es lo que se espera.

Se revisaron las 22 páginas de `lib/` y la pantalla de carga contra `develop` (`b59eaf1`), que ya incluye la SCRUM-617 (#44) y la edición del perfil de la SCRUM-612 (#45). Las rutas están en `lib/app/router/rutas.dart` y el enrutador en `lib/app/router/app_router.dart`.

## Regla general

- **Pantallas raíz** (login y las tres pestañas): no tienen flecha.
- **Pantallas secundarias:** tienen flecha, que vuelve a la pantalla anterior.
  - Se abren con `context.push`. Si se abren con `context.go`, la pila se reemplaza y ya no hay a dónde volver.
  - Si una secundaria se abre sin pila (por ejemplo, desde un enlace), la flecha lleva a un destino fijo, que se indica en la tabla.
- **El botón atrás de Android** hace lo mismo que la flecha. En las pestañas Actividad y Cuenta vuelve a Inicio; en Inicio y en el login sale de la app.
- **Formularios y chat:** si hay cambios sin guardar (o texto escrito sin enviar en el chat), al salir con la flecha o con el botón atrás se pide confirmación antes de descartarlos.
- **Diálogos y hojas inferiores** (confirmar ubicación, cotización, cancelar, evidencias, invitación) cierran con `Navigator.pop` y no entran en la regla.

## Decisiones (Juan Diego, 2026-10-26)

1. Al crear una solicitud, la flecha y el botón atrás del detalle llevan a **Mis solicitudes**.
2. En las pestañas **Actividad y Cuenta**, el botón atrás de Android vuelve a **Inicio**.
3. En el **chat**, si hay texto escrito sin enviar se pide confirmación, con la misma regla que los formularios.

## Cómo se aplica

Tres widgets con `PopScope` cubren la flecha y el botón atrás:

| Widget | Archivo | Qué hace |
|---|---|---|
| `EstructuraPrincipal` | `lib/app/shell/estructura_principal.dart` | En Actividad y Cuenta, atrás va a Inicio; en Inicio sale de la app |
| `AtrasConDestino` | `lib/shared/widgets/atras_con_destino.dart` | Con pila, atrás cierra la pantalla; sin pila, va al destino fijo |
| `ConfirmarSalida` | `lib/shared/widgets/confirmar_salida.dart` | Con cambios sin guardar, pregunta «¿Salir sin guardar?» antes de salir |

`ConfirmarSalida` solo cubre la flecha y el botón atrás. Cuando la pantalla termina por sí sola (guarda y hace `context.pop` o `context.go`), no pregunta.

## Pantallas raíz: sin flecha

| Pantalla | Ruta | Atrás | Cómo se cumple |
|---|---|---|---|
| Cargando | `/cargando` | Pantalla de paso | — |
| Iniciar sesión | `/iniciar-sesion` | Sin AppBar; sale de la app | — |
| Inicio (pestaña) | `/inicio` | Sin flecha; sale de la app | `EstructuraPrincipal` |
| Actividad (pestaña): Mis solicitudes, Servicios o Equipo según el rol | `/actividad` | Sin flecha; vuelve a Inicio | `EstructuraPrincipal` |
| Cuenta (pestaña) | `/cuenta` | Sin flecha; vuelve a Inicio | `EstructuraPrincipal` |

## Pantallas secundarias: con flecha

| Pantalla | Ruta | Cómo se llega | Flecha y atrás | Confirmación al salir |
|---|---|---|---|---|
| Registro de cliente | `/registro` | `push` desde el login | Vuelve al login | Sí, si hay datos escritos |
| Registro de técnico | `/registro/tecnico` | `push` desde el login | Vuelve al login | Sí, si hay datos escritos |
| Activar cuenta | `/activar` | `push` desde el login, o desde el enlace de invitación | Vuelve al login. Desde el enlace no hay pila y `AtrasConDestino` lleva al login | No |
| Editar perfil | `/cuenta/perfil` | `push` desde Cuenta | Vuelve a Cuenta | Sí, si cambió el nombre o el teléfono. Al guardar cierra sin preguntar |
| Notificaciones | `/notificaciones` | `push` desde Inicio y Cuenta | Vuelve a la pantalla anterior | No |
| Disponibilidad y cobertura | `/tecnico/disponibilidad` | `push` desde Inicio y desde la oferta | Vuelve a la pantalla anterior | Sí, si hay cambios sin guardar |
| Usuarios de la empresa | `/empresa/usuarios` | `push` desde Inicio | Vuelve a Inicio | No |
| Agregar usuario de la empresa | `/empresa/usuarios/nuevo` | `push` desde Usuarios de la empresa | Vuelve a la lista | Sí, si hay datos escritos. Al crear cierra sin preguntar |
| Agregar técnico (equipo) | `/equipo/nuevo` | `push` desde Equipo | Vuelve a Equipo | Sí, si hay datos escritos. Al crear cierra sin preguntar |
| Nueva solicitud | `/solicitudes/nueva` | `push` desde Inicio y Mis solicitudes | Vuelve a la pantalla anterior | Sí, si hay datos escritos. Al crear va al detalle sin preguntar |
| Detalle de la solicitud (cliente) | `/solicitudes/:id` | `push` desde la lista y el buzón; `go` al crear | Vuelve a la pantalla anterior. Recién creada o sin pila, `AtrasConDestino` lleva a Mis solicitudes | No |
| Servicio asignado (técnico) | `/tecnico/solicitudes/:id` | `push` desde Servicios, la oferta, el aviso y el buzón | Vuelve a la pantalla anterior | No |
| Chat del servicio | `/solicitudes/:id/chat` | `push` desde los dos detalles | Vuelve al detalle | Sí, si hay texto sin enviar |
| Pagar el servicio | `/solicitudes/:id/pagar` | `push` desde el detalle | Vuelve al detalle. Con el pago aprobado hace `pop`, así que no se repite el pago | Sí, si hay datos de tarjeta escritos |
| Comprobante de pago | `/pagos/:id/comprobante` | `push` desde el pago del detalle | Vuelve al detalle | No |

## Cambios de la SCRUM-617 (#44)

Lo que cambió respecto al inventario anterior, y dónde verlo en `develop` (`b59eaf1`):

1. **Registro y registro de técnico:** se abren con `push` en lugar de `go` (`inicio_sesion_page.dart`, líneas 131 y 149).
2. **Detalle de la solicitud:**
   - La casita que siempre iba a Inicio ahora es la flecha normal (`detalle_solicitud_page.dart`, línea 106).
   - `AtrasConDestino` lleva a Mis solicitudes cuando no hay pila (línea 94).
   - Al crear la solicitud se sigue abriendo con `go` (`nueva_solicitud_page.dart`, línea 106); por eso atrás lleva a Mis solicitudes y no cierra la app.
3. **Activar cuenta:** `AtrasConDestino` lleva al login cuando no hay pila (`activar_cuenta_page.dart`, línea 87).
4. **Pestañas Actividad y Cuenta:** el botón atrás vuelve a Inicio (`estructura_principal.dart`, línea 41).
5. **Confirmar antes de descartar cambios:** `ConfirmarSalida` en los 7 formularios (registro, registro de técnico, nueva solicitud, agregar usuario de la empresa, agregar técnico, pagar y disponibilidad) y en el chat. La SCRUM-612 (#45) lo agregó también en Editar perfil.
