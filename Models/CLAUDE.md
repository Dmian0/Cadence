# Models/

Structs y enums del dominio. Sin lógica de negocio compleja, solo data + propiedades computadas.

## SessionMode.swift

Enum con los 4 modos: `.deep`, `.aiWait`, `.review`, `.rest`.

### Propiedades por modo
| Propiedad | Tipo | Descripción |
|---|---|---|
| `label` | `String` | Nombre localizado (`NSLocalizedString`) |
| `duration` | `Int` | Duración en segundos (deep=1500, aiWait=300, review=600, rest=300) |
| `scoreWeight` | `Double` | Peso para Flow Score (deep=1.0, review=0.5, aiWait=0.2, rest=0.0) |
| `color` | `Color` | Color principal del modo (hex) |
| `lightBackground` | `Color` | Color claro para light mode (hex). **No usar para fondos de UI** — usar `color.opacity(0.15)` en su lugar para soporte dark mode |
| `sfSymbol` | `String` | Nombre del SF Symbol |
| `emoji` | `String` | Emoji representativo |
| `countsAsWork` | `Bool` | Si cuenta para break debt (deep, aiWait, review = true) |

### Extension: Color(hex:)
Inicializador de `Color` desde string hex (ej. `"#7F77DD"`). Definido aquí porque es donde se usan los colores hex. Acepta con o sin `#`.

---

## Session.swift

### Session (struct Codable, Identifiable)

Una sesión individual de trabajo.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | `UUID` | Identificador único |
| `mode` | `SessionMode` | Modo de la sesión |
| `startedAt` | `Date` | Inicio |
| `endedAt` | `Date?` | Fin (nil si activa) |
| `iterationCount` | `Int` | Iteraciones IA contadas |
| `wasCompleted` | `Bool` | Si completó la duración completa. Se marca `true` automáticamente cuando el timer llega a 0 (en `handleNaturalEnd`), no solo cuando el usuario hace click en "Terminar" |

**Propiedades computadas:**
- `duration` — Si `endedAt` es nil, usa `Date()` actual. Cuidado: esto significa que una sesión activa tiene duración creciente.
- `scoreContribution` — `scoreWeight` si completada, `scoreWeight * 0.3` si no.

### DayRecord (struct Codable)

Agregado de un día. Se construye on-demand desde `todaySessions` en el ViewModel, no se persiste directamente.

| Propiedad | Tipo | Descripción |
|---|---|---|
| `flowScore` | `Int` | 0–100, `min(100, (suma_pesos / 8.0) * 100)` |
| `totalFocusTime` | `TimeInterval` | Suma de duración de sesiones `.deep` + `.review` |
| `totalAIWaitTime` | `TimeInterval` | Suma de duración de sesiones `.aiWait` |
| `completionRate` | `Int` | % de sesiones completadas (legacy, ya no se muestra en UI) |
| `workSessionsSinceBreak` | `Int` | Sesiones de trabajo consecutivas desde el último `.rest` |
