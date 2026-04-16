# Cadence — Session Hierarchy & Flow (instrucciones para Claude Code)

Leer FEATURES.md antes de empezar para contexto completo del proyecto.

---

## Concepto central

Las sesiones tienen dos tipos:

- **Sesión padre** — iniciada desde un tab manualmente. Tiene dot grande en el historial.
- **Sub-sesión** — iniciada desde un botón de acceso rápido dentro de otra sesión activa.
  Tiene dot pequeño. La sesión padre queda suspendida en background.

La jerarquía SOLO existe cuando se usa un botón de acceso rápido.
Cambiar de tab manualmente con una sesión activa NO crea automáticamente una sub-sesión
— en ese caso se muestra un banner de elección al usuario.

---

## Flujo completo de botones de acceso rápido

Tres botones que crean el ciclo de trabajo con IA:

```
[Deep Work]   →  "Esperando respuesta IA — pausar"  →  [AI Wait]
[AI Wait]     →  "Llegó la respuesta — revisar"      →  [Review]
[Review]      →  "Volver a Deep Work"                →  [Deep Work] (reanuda)
```

Cada botón crea una sub-sesión del modo destino, suspendiendo la sesión padre.
Al regresar a Deep Work desde Review, se reanuda la sesión padre original
con el tiempo exacto donde quedó.

### Visibilidad de los botones
- "Esperando respuesta IA — pausar" → visible en Deep Work con sesión activa (ya existe)
- "Llegó la respuesta — revisar"     → visible en AI Wait con sesión activa (nuevo)
- "Volver a Deep Work"               → visible en Review con sesión activa (nuevo)

Los tres botones tienen el mismo estilo visual: borde punteado con el color del modo destino.

---

## Flujo al cambiar de tab manualmente con sesión activa

Cuando el usuario toca un tab distinto mientras hay una sesión corriendo,
mostrar un banner inline dentro del panel (no un modal, no un sheet):

```
┌─────────────────────────────────────────────────┐
│  Deep Work activo · 10:32 restantes             │
│                                                 │
│  [  Continuar como sub-sesión  ]  ← prominente  │
│                                                 │
│       nueva sesión independiente  ← link small  │
└─────────────────────────────────────────────────┘
```

**"Continuar como sub-sesión" (botón principal)**
- Estilo: fondo con el color del modo destino (opacity 0.15), borde sólido, texto normal
- Acción: suspende la sesión actual → inicia sub-sesión del modo seleccionado

**"nueva sesión independiente" (opción secundaria)**
- Estilo: texto pequeño (11px), color secundario, sin borde, sin fondo — link style
- Acción: cierra la sesión actual como completada (el usuario eligió terminarla)
  → inicia sesión nueva e independiente del modo seleccionado

El banner reemplaza temporalmente el área de controles (play/pause/reset/skip).
Si el usuario no toca ninguna opción y cierra el popover, la sesión original continúa
corriendo (no se hace nada).

---

## Cambios al modelo de datos

### Session.swift

```swift
struct Session: Codable, Identifiable {
    // Campos existentes — no modificar
    let id: UUID
    let mode: SessionMode
    let startedAt: Date
    var endedAt: Date?
    var iterationCount: Int
    var wasCompleted: Bool

    // Nuevos campos
    var isSubSession: Bool       // true cuando fue iniciada como sub-sesión
    var parentSessionId: UUID?   // id de la sesión padre (nil si es independiente)
    var subSessions: [Session]   // sub-sesiones completadas dentro de esta (solo en padre)

    init(mode: SessionMode, parentId: UUID? = nil) {
        self.id               = UUID()
        self.mode             = mode
        self.startedAt        = Date()
        self.endedAt          = nil
        self.iterationCount   = 0
        self.wasCompleted     = false
        self.isSubSession     = parentId != nil
        self.parentSessionId  = parentId
        self.subSessions      = []
    }
}
```

### DayRecord — flow score

El flow score solo considera sesiones padre (no sub-sesiones directamente).
Las sub-sesiones contribuyen indirectamente a través de la sesión padre.

```swift
var flowScore: Int {
    let parentSessions = sessions.filter { !$0.isSubSession }
    let raw = parentSessions.reduce(0.0) { $0 + $1.scoreContribution }
    return min(100, Int((raw / 8.0) * 100))
}
```

---

## Cambios al ViewModel

### SessionViewModel.swift — estado nuevo

```swift
// Sesión padre suspendida (cuando hay sub-sesión activa)
@Published private(set) var suspendedParentSession: Session? = nil
@Published private(set) var suspendedParentSeconds: Int = 0

// Banner de elección al cambiar tab con sesión activa
@Published var showSubSessionChoice: Bool = false
@Published private(set) var pendingMode: SessionMode? = nil
```

### setMode() — lógica completa

```swift
func setMode(_ mode: SessionMode) {
    guard mode != currentMode else { return }

    if activeSession != nil {
        // Hay sesión activa — mostrar banner de elección
        pendingMode = mode
        showSubSessionChoice = true
        timer.pause()
    } else {
        // No hay sesión activa — cambio limpio
        applyModeChange(mode, asSubSession: false)
    }
}

// Usuario eligió "Continuar como sub-sesión"
func confirmAsSubSession() {
    guard let mode = pendingMode else { return }
    showSubSessionChoice = false

    // Suspender la sesión actual
    suspendedParentSession = activeSession
    suspendedParentSeconds = timer.secondsRemaining
    timer.pause()

    // Iniciar sub-sesión
    currentMode = mode
    activeSession = Session(mode: mode, parentId: suspendedParentSession?.id)
    iterationCount = 0
    timer.load(seconds: mode.duration)
    pendingMode = nil
}

// Usuario eligió "nueva sesión independiente"
func confirmAsIndependent() {
    guard let mode = pendingMode else { return }
    showSubSessionChoice = false

    // Cerrar sesión actual como completada (el usuario eligió terminarla)
    endSession(completed: true)

    // Limpiar cualquier padre suspendido
    suspendedParentSession = nil
    suspendedParentSeconds = 0

    // Iniciar sesión nueva independiente
    applyModeChange(mode, asSubSession: false)
    pendingMode = nil
}

// Usuario cerró el popover sin elegir — reanudar lo que tenía
func cancelModeChange() {
    showSubSessionChoice = false
    pendingMode = nil
    if activeSession != nil { timer.start() }
}

private func applyModeChange(_ mode: SessionMode, asSubSession: Bool) {
    currentMode = mode
    activeSession = nil
    iterationCount = 0
    timer.load(seconds: mode.duration)
}
```

### Botones de acceso rápido — acción directa (sin banner)

```swift
// "Esperando respuesta IA — pausar" desde Deep Work
func activateAIWait() {
    suspendSession()
    startSubSession(mode: .aiWait)
}

// "Llegó la respuesta — revisar" desde AI Wait
func activateReview() {
    completeCurrentSubSession()
    startSubSession(mode: .review)
}

// "Volver a Deep Work" desde Review
func returnToDeepWork() {
    completeCurrentSubSession()
    resumeParentSession()
}

private func suspendSession() {
    suspendedParentSession = activeSession
    suspendedParentSeconds = timer.secondsRemaining
    timer.pause()
}

private func startSubSession(mode: SessionMode) {
    currentMode = mode
    activeSession = Session(mode: mode, parentId: suspendedParentSession?.id)
    iterationCount = 0
    timer.load(seconds: mode.duration)
    timer.start()
}

private func completeCurrentSubSession() {
    guard var sub = activeSession else { return }
    sub.endedAt = Date()
    sub.wasCompleted = true
    sub.iterationCount = iterationCount
    suspendedParentSession?.subSessions.append(sub)
    activeSession = nil
    timer.pause()
}

private func resumeParentSession() {
    guard let parent = suspendedParentSession else { return }
    currentMode = parent.mode
    activeSession = parent
    iterationCount = parent.iterationCount
    timer.load(seconds: suspendedParentSeconds)
    timer.start()
    suspendedParentSession = nil
    suspendedParentSeconds = 0
}
```

### endSession() — guardar sub-sesiones con el padre

```swift
func endSession(completed: Bool) {
    guard var session = activeSession else { return }
    session.endedAt = Date()
    session.wasCompleted = completed
    session.iterationCount = iterationCount

    timer.stop()
    activeSession = nil
    iterationCount = 0
    showSubSessionChoice = false

    // Si hay padre suspendido, terminar también el padre
    if var parent = suspendedParentSession {
        parent.endedAt = Date()
        parent.wasCompleted = completed
        parent.subSessions.append(session)
        todaySessions.append(parent)
        suspendedParentSession = nil
        suspendedParentSeconds = 0
    } else {
        todaySessions.append(session)
    }

    updateStreak()
    store.save(sessions: todaySessions, streak: streak)
}
```

---

## Cambios a las vistas

### PopoverView.swift — banner de elección

Reemplaza el área de controles cuando `vm.showSubSessionChoice == true`:

```swift
if vm.showSubSessionChoice, let pending = vm.pendingMode {
    SubSessionChoiceBanner(
        currentMode: vm.currentMode,
        currentTimeRemaining: vm.timer.displayString,
        destinationMode: pending,
        onSubSession: { vm.confirmAsSubSession() },
        onIndependent: { vm.confirmAsIndependent() }
    )
    .transition(.opacity.combined(with: .scale(scale: 0.97)))
} else if vm.showOverflowBanner {
    OverflowBannerView(vm: vm)
} else {
    ControlsView(vm: vm)
}
```

### SubSessionChoiceBanner (nueva vista)

```swift
struct SubSessionChoiceBanner: View {
    let currentMode: SessionMode
    let currentTimeRemaining: String
    let destinationMode: SessionMode
    let onSubSession: () -> Void
    let onIndependent: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            // Info de la sesión activa
            HStack(spacing: 4) {
                Text(currentMode.emoji).font(.system(size: 11))
                Text("\(currentMode.label) · \(currentTimeRemaining)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            // Botón principal — sub-sesión
            Button(action: onSubSession) {
                Text(NSLocalizedString("continue_as_subsession", comment: ""))
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(destinationMode.color.opacity(0.15))
                    .foregroundColor(destinationMode.color)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(destinationMode.color.opacity(0.4), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)

            // Opción secundaria — sesión independiente (link style)
            Button(action: onIndependent) {
                Text(NSLocalizedString("new_independent_session", comment: ""))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(currentMode.lightBackground.opacity(0.5))
        .cornerRadius(10)
    }
}
```

### Botones de acceso rápido — actualizar los tres

```swift
// En Deep Work activo:
Button { vm.activateAIWait() } label: {
    // "Esperando respuesta IA — pausar" (ya existe, solo cambiar acción)
}

// En AI Wait activo (nuevo):
Button { vm.activateReview() } label: {
    HStack(spacing: 6) {
        Circle().fill(Color(hex: "#EF9F27")).frame(width: 6, height: 6)
        Text(NSLocalizedString("response_arrived_review", comment: ""))
            .font(.system(size: 11))
            .foregroundColor(Color(hex: "#854F0B"))
    }
    // mismo estilo que el botón existente pero con color ámbar
}

// En Review activo (nuevo):
Button { vm.returnToDeepWork() } label: {
    HStack(spacing: 6) {
        Circle().fill(Color(hex: "#7F77DD")).frame(width: 6, height: 6)
        Text(NSLocalizedString("return_to_deep_work", comment: ""))
            .font(.system(size: 11))
            .foregroundColor(Color(hex: "#534AB7"))
    }
    // mismo estilo con color púrpura
}
```

### HistoryDotsView — dots grandes y pequeños

```swift
// Dot grande = sesión padre o sesión independiente
// Dot pequeño = sub-sesión

private func dotSize(for session: Session) -> CGFloat {
    session.isSubSession ? 7 : 10
}

private func dotOpacity(for session: Session) -> Double {
    session.wasCompleted ? 1.0 : 0.35
}
```

En el loop de dots, usar `dotSize()` y `dotOpacity()` por sesión.

---

## Strings nuevos para Localizable.strings

```
// ES
"continue_as_subsession"    = "Continuar como sub-sesión";
"new_independent_session"   = "nueva sesión independiente";
"response_arrived_review"   = "Llegó la respuesta — revisar";
"return_to_deep_work"       = "Volver a Deep Work";

// EN
"continue_as_subsession"    = "Continue as sub-session";
"new_independent_session"   = "new independent session";
"response_arrived_review"   = "Response arrived — review";
"return_to_deep_work"       = "Back to Deep Work";
```

---

## Resumen de archivos a tocar

| Archivo | Cambio |
|---------|--------|
| `Models/Session.swift` | Agregar `isSubSession`, `parentSessionId`, `subSessions` |
| `ViewModel/SessionViewModel.swift` | Lógica completa de jerarquía, banner, botones rápidos |
| `Views/PopoverView.swift` | `SubSessionChoiceBanner`, tres botones rápidos, dots por tamaño |
| `Resources/es.lproj/Localizable.strings` | 4 strings nuevos |
| `Resources/en.lproj/Localizable.strings` | 4 strings nuevos |

## Lo que NO tocar

- `TimerEngine.swift`
- `AppDelegate.swift`
- `Store/DayStore.swift`
- `Models/SessionMode.swift`
- La lógica de Break Debt
- El Gentle Overflow
