# ViewModel/

Cerebro de la app. Un solo archivo con el ViewModel principal y el enum BreakDebtLevel.

## SessionViewModel.swift

`@MainActor ObservableObject`. Orquesta: TimerEngine, DayStore, estado de UI.

### Estado publicado (@Published)
| Propiedad | Tipo | Descripción |
|---|---|---|
| `currentMode` | `SessionMode` | Modo activo |
| `activeSession` | `Session?` | Sesión en curso (nil si no hay) |
| `iterationCount` | `Int` | Contador de iteraciones IA actual |
| `showOverflowBanner` | `Bool` | Mostrar banner "+5 min / Terminar" |
| `showUndoModeChange` | `Bool` | Mostrar píldora de undo (3s) |
| `todaySessions` | `[Session]` | Todas las sesiones del día |
| `streak` | `Int` | Sesiones deep completadas hoy |

### Sub-objetos
- `timer: TimerEngine` — countdown. Sus cambios se forwardean a `objectWillChange` para que SwiftUI re-renderice.
- `store: DayStore` — persistencia.

### Métodos públicos clave
| Método | Qué hace |
|---|---|
| `setMode(_:)` | Cambia modo. Si hay sesión activa: guarda estado para undo, termina sesión como incompleta, muestra píldora undo 3s |
| `togglePlayPause()` | Si no hay sesión → crea una y arranca. Si hay → toggle pause/resume |
| `startSession()` | Crea `Session`, carga timer, arranca |
| `endSession(completed:)` | Guarda sesión en `todaySessions`, persiste, actualiza streak |
| `skipSession()` | Termina como incompleta, avanza a Break (si deep) o Deep (si otro) |
| `resetSession()` | Para timer, limpia sesión activa, recarga duración del modo |
| `extendSession()` | Oculta banner, llama `timer.extend(by: 300)` |
| `finishFromOverflow()` | Termina sesión como completada desde el overflow banner |
| `undoModeChange()` | Restaura modo, sesión, timer, iteraciones previos. Remueve la sesión incompleta del historial |
| `reloadData()` | Reset total para dev: para timer, limpia estado, recarga desde UserDefaults |

### Flujo: Timer llega a 0 (`handleNaturalEnd`)
1. Si modo es `.rest` → `endSession(completed: true)` + auto-switch a `.deep`
2. Si modo es trabajo → marca `activeSession?.wasCompleted = true` + muestra overflow banner + beep

### Undo state (privado)
Guarda: `previousMode`, `previousSession`, `previousSecondsRemaining`, `previousIterationCount`.
Timer de 3s con `Just().delay()`. Al expirar, limpia el estado de undo.

### Computed stats (conectan DayRecord → UI)
- `flowScore`, `focusTimeFormatted`, `aiWaitTimeFormatted`, `breakDebt`, `breakDebtLevel`
- `recentHistory` — últimas 10 sesiones (`.suffix(10)`)
- `completionRate` — legacy, ya no se usa en UI pero sigue disponible

---

## BreakDebtLevel (enum)

Definido en el mismo archivo. Niveles: `.ok`, `.warning`, `.critical`.

| Nivel | Rango | Color | Label (localizado) |
|---|---|---|---|
| `.ok` | 0–2 | verde `#1D9E75` | "Al día" / "On track" |
| `.warning` | 3–4 | naranja `#EF9F27` | "Toma un break pronto" / "Take a break soon" |
| `.critical` | 5+ | rojo `#E24B4A` | "Break necesario" / "Break needed" |
