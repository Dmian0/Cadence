# ViewModel/

Cerebro de la app. Un solo archivo con el ViewModel principal, OverflowContext y BreakDebtLevel enums.

## SessionViewModel.swift

`@MainActor ObservableObject`. Orquesta: TimerEngine, DayStore, estado de UI, jerarquía de sub-sesiones.

### Estado publicado (@Published)
| Propiedad | Tipo | Descripción |
|---|---|---|
| `currentMode` | `SessionMode` | Modo activo |
| `activeSession` | `Session?` | Sesión en curso (nil si no hay) |
| `iterationCount` | `Int` | Contador de iteraciones IA actual |
| `showOverflowBanner` | `Bool` | Mostrar banner overflow (contextual según `overflowContext`) |
| `overflowContext` | `OverflowContext` | Tipo de overflow: `.normal`, `.aiWaitSub`, `.reviewSub` |
| `suspendedParentSession` | `Session?` | Sesión padre suspendida cuando hay sub-sesión activa |
| `suspendedParentSeconds` | `Int` | Segundos restantes del padre al momento de suspender |
| `showSubSessionChoice` | `Bool` | Mostrar banner de elección sub-sesión vs independiente |
| `pendingMode` | `SessionMode?` | Modo destino pendiente mientras se muestra el banner |
| `todaySessions` | `[Session]` | Todas las sesiones del día |
| `streak` | `Int` | Sesiones deep completadas hoy |

### Sub-objetos
- `timer: TimerEngine` — countdown. Sus cambios se forwardean a `objectWillChange` para que SwiftUI re-renderice.
- `store: DayStore` — persistencia.

### Métodos públicos clave
| Método | Qué hace |
|---|---|
| `setMode(_:)` | Cambia modo. Si el modo destino es el del padre suspendido: reanuda el padre sin banner. Si hay sesión activa (otro modo): muestra banner de elección (`showSubSessionChoice`). Si no: cambio limpio |
| `confirmAsSubSession()` | Desde banner: suspende padre (o completa sub actual), inicia sub-sesión del modo pendiente |
| `confirmAsIndependent()` | Desde banner: termina sesión **como incompleta** (user abandonó el flujo), inicia nueva independiente. Si había padre suspendido, se cierra también como incompleto |
| `cancelModeChange()` | Cierra banner sin acción. Si el timer estaba en overflow, restaura el overflow banner en vez de reanudar el timer |
| `activateAIWait()` | Quick-action: suspende sesión actual → inicia AI Wait sub-sesión |
| `activateReview()` | Quick-action: completa AI Wait sub → inicia Review sub-sesión |
| `returnToDeepWork()` | Quick-action: completa Review sub → reanuda sesión padre |
| `togglePlayPause()` | Si no hay sesión → crea una y arranca. Si hay → toggle pause/resume |
| `startSession()` | Crea `Session`, carga timer, arranca |
| `endSession(completed:)` | Guarda sesión en `todaySessions`. Si hay padre suspendido: añade sub al padre, termina padre, solo padre va a `todaySessions`. Resetea timer a duración original del modo |
| `skipSession()` | Termina como incompleta, avanza a Break (si deep) o Deep (si otro) |
| `resetSession()` | Para timer, limpia sesión activa, recarga duración del modo |
| `extendSession()` | Oculta banner, llama `timer.extend(by: 300)` |
| `finishFromOverflow()` | Termina sesión como completada desde overflow banner |
| `reviewOverflowReturnToParent()` | Overflow Review sub: completa sub, reanuda padre |
| `aiWaitOverflowStartReview()` | Overflow AI Wait sub: completa sub, inicia Review sub |
| `finishReviewFromOverflow()` | Overflow Review sub: termina sesión (sub + padre) |
| `reloadData()` | Reset total para dev: para timer, limpia todo el estado, recarga desde UserDefaults |

### Day rollover
- `init()` se suscribe a `.NSCalendarDayChanged`. Al cambio de día, `handleDayRollover()` llama `loadToday()` solo si no hay sesión activa (para no interrumpir).
- Si hay sesión activa durante el cambio de día, se guardará contra la key del día nuevo en el próximo `store.save`.

### Flujo: Timer llega a 0 (`handleNaturalEnd`)
1. Si modo es `.rest` → `endSession(completed: true)` + auto-switch a `.deep`
2. Si es sub-sesión AI Wait → `overflowContext = .aiWaitSub` + overflow banner
3. Si es sub-sesión Review → `overflowContext = .reviewSub` + overflow banner
4. Si modo es trabajo normal → `overflowContext = .normal` + overflow banner + beep

### Private helpers (sub-sesiones)
- `suspendSession()` — guarda sesión activa + segundos restantes, para timer
- `startSubSession(mode:)` — crea Session con parentId, carga timer, arranca
- `completeCurrentSubSession()` — marca completada, añade al array `parent.subSessions`
- `resumeParentSession()` — restaura modo, sesión, timer con segundos guardados

### Computed stats (conectan DayRecord → UI)
- `flowScore`, `focusTimeFormatted`, `aiWaitTimeFormatted`, `breakDebt`, `breakDebtLevel`
- `recentHistory` — últimas 14 sesiones **flatten** (padres + subs) ordenadas por `startedAt`
- `totalSessionCount` — total incluyendo sub-sessions (para el contador "hoy, N ses.")
- `completionRate` — legacy, ya no se usa en UI pero sigue disponible

---

## OverflowContext (enum)

Definido en el mismo archivo. Determina qué botones muestra el overflow banner.

| Caso | Contexto | Botones |
|---|---|---|
| `.normal` | Sesión independiente | "+5 min" / "Terminar" |
| `.aiWaitSub` | AI Wait sub-sesión | "+5 min" / "Llegó la respuesta — revisar" |
| `.reviewSub` | Review sub-sesión | "+5 min" / "Terminar review" / "Volver a Deep Work" |

---

## BreakDebtLevel (enum)

Definido en el mismo archivo. Niveles: `.ok`, `.warning`, `.critical`.

| Nivel | Rango | Color | Label (localizado) |
|---|---|---|---|
| `.ok` | 0–2 | verde `#1D9E75` | "Al día" / "On track" |
| `.warning` | 3–4 | naranja `#EF9F27` | "Toma un break pronto" / "Take a break soon" |
| `.critical` | 5+ | rojo `#E24B4A` | "Break necesario" / "Break needed" |
