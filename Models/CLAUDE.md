# Models/

Structs y enums del dominio. Sin lógica de negocio compleja, solo data + propiedades computadas.

## SessionMode.swift

Enum con los 4 modos: `.deep`, `.aiWait`, `.review`, `.rest`.

### Propiedades por modo
| Propiedad | Tipo | Descripción |
|---|---|---|
| `label` | `String` | Nombre localizado (`NSLocalizedString`) |
| `duration` | `Int` | Duración en segundos. **Configurable** via `SettingsStore` (ver Store/CLAUDE.md). Defaults: deep=1500, aiWait=300, review=600, rest=300 |
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
| Campo | Tipo | Descripción |
|---|---|---|
| `id` | `UUID` | Identificador único |
| `mode` | `SessionMode` | Modo de la sesión |
| `startedAt` | `Date` | Inicio |
| `endedAt` | `Date?` | Fin (nil si activa) |
| `iterationCount` | `Int` | Iteraciones IA contadas |
| `wasCompleted` | `Bool` | Si la sesión duró **≥ 80%** de la duración configurada del modo. Se calcula en `markEnded(completed:)` al cerrar. Un skip explícito (`completed: false`) fuerza `false` sin importar la duración |
| `isSubSession` | `Bool` | `true` si fue iniciada como sub-sesión (derivado de `parentId != nil` en init) |
| `parentSessionId` | `UUID?` | ID de la sesión padre (nil si es independiente) |
| `subSessions` | `[Session]` | Sub-sesiones completadas dentro de esta (solo relevante en sesiones padre) |

**Init:** `init(mode:parentId:)` — `parentId` es opcional (`nil` por defecto). Si se pasa un parentId, `isSubSession` se marca `true`.

**Custom Codable decoder:** Implementa `init(from decoder:)` con `decodeIfPresent` + defaults para los 3 campos nuevos. Esto asegura backward compatibility con sesiones persistidas antes de la jerarquía.

**Propiedades computadas:**
- `duration` — Si `endedAt` es nil, usa `Date()` actual. Cuidado: esto significa que una sesión activa tiene duración creciente.
- `scoreContribution` — `scoreWeight` si completada, `scoreWeight * 0.3` si no.

**Método mutante:**
- `markEnded(completed:)` — cierra la sesión: setea `endedAt = Date()` y calcula `wasCompleted` con umbral 80% de la duración configurada del modo. Si `completed: false` fuerza `wasCompleted = false` (skip explícito). Usar siempre que una sesión se cierre en vez de mutar `endedAt`/`wasCompleted` directamente.

### DayRecord (struct Codable)

Agregado de un día. Se construye on-demand desde `todaySessions` en el ViewModel, no se persiste directamente.

| Propiedad | Tipo | Descripción |
|---|---|---|
| `flowScore` | `Int` | 0–100, solo sesiones padre (`!isSubSession`). `min(100, (suma_pesos / 8.0) * 100)` |
| `totalFocusTime` | `TimeInterval` | Suma de duración de sesiones `.deep` + `.review`. **Incluye sub-sessions** vía flatten. Excluye sesiones < 6 s (floor anti-ruido) |
| `totalAIWaitTime` | `TimeInterval` | Suma de duración de sesiones `.aiWait`. **Incluye sub-sessions** vía flatten. Excluye sesiones < 6 s |
| `completionRate` | `Int` | % de sesiones completadas (legacy, ya no se muestra en UI) |
| `workSessionsSinceBreak` | `Int` | Sesiones de trabajo consecutivas desde el último `.rest` |
