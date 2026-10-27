# Navegación de la app: inventario de pantallas y regla de la flecha

Inventario de la SCRUM-616 (historia SCRUM-615). Lo usan la SCRUM-617, que corrige la flecha y el botón atrás, y la SCRUM-618, que lo prueba.

Se revisaron las 21 páginas de `lib/` y la pantalla de carga contra `develop` (`1ba9769`). Las rutas están en `lib/app/router/rutas.dart` y el enrutador en `lib/app/router/app_router.dart`.

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

## Pantallas raíz: sin flecha

| Pantalla | Ruta | Comportamiento actual | Regla |
|---|---|---|---|
| Cargando | `/cargando` | Pantalla de paso | Cumple |
| Iniciar sesión | `/iniciar-sesion` | Sin AppBar; atrás sale de la app | Cumple |
| Inicio (pestaña) | `/inicio` | Sin flecha; atrás sale de la app | Cumple |
| Actividad (pestaña): Mis solicitudes, Servicios o Equipo según el rol | `/actividad` | Sin flecha; atrás cierra la app | **Falla.** Atrás vuelve a Inicio |
| Cuenta (pestaña) | `/cuenta` | Sin flecha; atrás cierra la app | **Falla.** Atrás vuelve a Inicio |

## Pantallas secundarias: con flecha

| Pantalla | Ruta | Cómo se llega | Flecha hoy | Regla |
|---|---|---|---|---|
| Registro de cliente | `/registro` | `go` desde el login | **No**; atrás cierra la app | Abrir con `push`; la flecha vuelve al login. Formulario: confirmar si hay datos |
| Registro de técnico | `/registro/tecnico` | `go` desde el login | **No**; atrás cierra la app | Igual que el registro de cliente |
| Activar cuenta | `/activar` | `push` desde el login, o desde el enlace de invitación | Sí desde el login; **no** desde el enlace, porque no hay pila | Sin pila, la flecha lleva al login |
| Notificaciones | `/notificaciones` | `push` desde Inicio y Cuenta | Sí | Cumple |
| Disponibilidad y cobertura | `/tecnico/disponibilidad` | `push` desde Inicio y desde la oferta | Sí | **Falla.** Confirmar si hay localidades sin guardar |
| Usuarios de la empresa | `/empresa/usuarios` | `push` desde Inicio | Sí | Cumple |
| Agregar usuario de la empresa | `/empresa/usuarios/nuevo` | `push` | Sí | **Falla.** Formulario sin confirmación |
| Agregar técnico (equipo) | `/equipo/nuevo` | `push` desde Equipo | Sí | **Falla.** Formulario sin confirmación |
| Nueva solicitud | `/solicitudes/nueva` | `push` desde Inicio y Mis solicitudes | Sí | **Falla.** Formulario sin confirmación |
| Detalle de la solicitud (cliente) | `/solicitudes/:id` | `push` desde la lista y el buzón; `go` al crear | **No**: muestra una casita que siempre va a Inicio. Recién creada, atrás cierra la app | Flecha que vuelve a la pantalla anterior. Recién creada o sin pila: va a Mis solicitudes |
| Servicio asignado (técnico) | `/tecnico/solicitudes/:id` | `push` desde Servicios, la oferta y el aviso | Sí | Cumple |
| Chat del servicio | `/solicitudes/:id/chat` | `push` desde los dos detalles | Sí | **Falla.** Confirmar si hay texto sin enviar |
| Pagar el servicio | `/solicitudes/:id/pagar` | `push` desde el detalle | Sí. Con pago aprobado hace `pop`, así que no se repite el pago | **Falla.** Formulario de tarjeta sin confirmación |
| Comprobante de pago | `/pagos/:id/comprobante` | `push` desde el pago | Sí | Cumple |

Ninguna página usa `PopScope`, así que hoy no hay confirmación al salir ni manejo propio del botón atrás.

## Cambios para la SCRUM-617

1. **Registro y registro de técnico:** abrirlos con `push` en lugar de `go` (`inicio_sesion_page.dart`, líneas 131 y 148).
2. **Detalle de la solicitud:**
   - Cambiar la casita (`detalle_solicitud_page.dart`, línea 104) por la flecha normal.
   - Si no hay pila, la flecha va a Mis solicitudes.
   - Al crear la solicitud (`nueva_solicitud_page.dart`, línea 105), atrás también debe llevar a Mis solicitudes, no cerrar la app.
3. **Activar cuenta:** si no hay pila, la flecha lleva al login.
4. **Pestañas Actividad y Cuenta:** el botón atrás de Android vuelve a Inicio.
5. **Confirmar antes de descartar cambios** en 7 formularios (registro, registro de técnico, nueva solicitud, agregar usuario de la empresa, agregar técnico, pagar y disponibilidad) y en el chat cuando hay texto sin enviar.
