# Cadence — Contexto del proyecto

## Qué es Cadence

Pomodoro timer para macOS diseñado para desarrolladores que trabajan con IA. Vive en la **menubar** (no tiene ventana principal ni icono en Dock). El diferenciador clave vs. otros Pomodoros: tiene un modo "AI Wait" para trackear el tiempo que pasas esperando respuestas de IA, separándolo del trabajo profundo real.

## Filosofía de diseño

- **Menubar-only**: La app es un `NSStatusItem` con un `NSPopover`. No hay `NSWindow`. El entry point (`CadenceApp.swift`) no declara ninguna `WindowGroup`, solo un `Settings` vacío como placeholder.
- **Gentle overflow**: Cuando el timer llega a cero, NO hay alarma agresiva. Se muestra un banner suave con opciones "+5 min" o "Terminar". La sesión se marca como completada automáticamente al llegar a cero — el overflow es tiempo bonus.
- **Sin dependencias externas**: Todo es SwiftUI + AppKit + Combine + Foundation. Cero SPM packages, cero CocoaPods. Los iconos son SF Symbols, los colores son hex inline.
- **Multi-idioma**: Soporte ES/EN via `Localizable.strings` en `Resources/`. Todos los textos visibles usan `NSLocalizedString`. El idioma se puede cambiar desde el menú contextual (right-click en menubar) → Language.
- **Deployment target**: macOS 13.0+
- **Dark mode friendly**: Todos los fondos de UI usan `mode.color.opacity(0.15)` en vez de colores claros hardcodeados, para adaptarse automáticamente a light/dark mode.

## Los 4 modos de sesión

| Modo | Duración | Peso en Flow Score | Color | Símbolo |
|---|---|---|---|---|
| Deep Work | 25 min | 1.0 | `#7F77DD` (púrpura) | bolt.fill |
| AI Wait | 5 min | 0.2 | `#1D9E75` (verde) | hourglass |
| Review | 10 min | 0.5 | `#EF9F27` (naranja) | eye.fill |
| Break | 5 min | 0.0 | `#378ADD` (azul) | cloud.fill |

## Arquitectura (MVVM)

```
CadenceApp.swift          → @main, inyecta AppDelegate
AppDelegate.swift         → NSStatusItem + NSPopover + context menu, @MainActor
│
├── Engine/
│   └── TimerEngine       → Combine-based 1Hz countdown, overflow, extend
│
├── Models/
│   ├── Session           → Struct Codable. Una sesión individual + DayRecord
│   └── SessionMode       → Enum 4 modos, colores, duraciones, pesos, Color(hex:) extension
│
├── Store/
│   └── DayStore          → Persistencia con UserDefaults (JSON por día)
│
├── ViewModel/
│   └── SessionViewModel  → @MainActor, ObservableObject. Cerebro de la app + OverflowContext + BreakDebtLevel enums
│
├── Views/
│   ├── PopoverView       → Panel principal (280px). Contiene: SubSessionChoiceBanner,
│   │                       ControlsView, OverflowBannerView (contextual), IterationCounterView,
│   │                       HistoryDotsView, StatsRowView, CircleButton, PillButtonStyle, StatCell
│   ├── TimerRingView     → Anillo circular de progreso con pulse en overflow + checkmark
│   └── ModeTabsView      → Tabs horizontales para los 4 modos
│
└── Resources/
    ├── es.lproj/Localizable.strings
    └── en.lproj/Localizable.strings
```

## Mecánicas clave

### Flow Score (0–100)
- Reemplaza el antiguo "Completadas %". Se muestra en StatsRowView.
- Solo sesiones padre/independientes cuentan (no sub-sesiones directamente).
- Cada sesión completada suma su `scoreWeight` (deep=1.0, review=0.5, aiWait=0.2, rest=0).
- Sesiones incompletas suman solo 30% de su peso.
- 8 deep work sessions completadas = 100 puntos.
- Fórmula: `min(100, (suma_pesos / 8.0) * 100)`

### Break Debt
- Cuenta sesiones de trabajo consecutivas sin break.
- 0–2: OK (verde, no visible). 3–4: Warning (naranja). 5+: Crítico (rojo).
- Se calcula recorriendo el historial del día en reversa hasta encontrar un `.rest`.

### Streak
- v1: cuenta de sesiones deep completadas **hoy** (no persiste entre días).

### Iteration Counter
- Botón manual para contar "iteraciones IA" dentro de una sesión.
- Se guarda en cada `Session.iterationCount`.
- Visible solo durante sesiones activas (no en break).

### Session Hierarchy (Sub-sesiones)
- Las sesiones tienen dos tipos: **padre** (iniciada desde tab) y **sub-sesión** (desde botón de acceso rápido).
- Ciclo de trabajo con IA: Deep Work → AI Wait (sub) → Review (sub) → reanuda Deep Work padre.
- La sesión padre se suspende con su tiempo restante guardado en `suspendedParentSession`/`suspendedParentSeconds`.
- Sub-sesiones se almacenan en el array `parent.subSessions`, no directamente en `todaySessions`.
- Al cambiar tab con sesión activa: aparece banner de elección (sub-sesión vs independiente).
- Los botones de acceso rápido crean sub-sesiones directamente sin banner.
- `endSession()` con padre suspendido: termina ambos, solo el padre va a `todaySessions`.

### Gentle Overflow
- Timer llega a 0 → sesión se marca `wasCompleted = true` automáticamente.
- Banner contextual según tipo de sesión (`OverflowContext`):
  - Sesión normal: "+5 min" / "Terminar"
  - AI Wait sub-sesión: "+5 min" / "Llegó la respuesta — revisar"
  - Review sub-sesión: "+5 min" / "Terminar review" / "Volver a Deep Work"
- Checkmark verde en el ring + texto "completada".
- `extend()` suma tiempo (no reemplaza) y recalcula `totalSeconds` para el anillo.
- Tras cada +5 min, si el tiempo expira se vuelve a mostrar el banner (repetible N veces).
- Al terminar, el timer se resetea a la duración original del modo.

### Persistencia
- `UserDefaults` con key `cadence_sessions_YYYY-MM-DD` por día.
- `cadence_streak` para el streak global.
- Serialización JSON via Codable.

### Localización
- ES y EN soportados via `Resources/{lang}.lproj/Localizable.strings`.
- Todos los textos de UI usan `NSLocalizedString("key", comment: "")`.
- `SessionMode.label` también está localizado.
- Cambio de idioma: right-click menubar → Language → seleccionar. Requiere reinicio de la app para aplicar completamente (limitación de `NSLocalizedString` cache).

## Consideraciones para desarrollo

### Nested ObservableObject (fix aplicado)
- `SessionViewModel` tiene `let timer = TimerEngine()` — ambos son `ObservableObject`.
- SwiftUI solo observa el `objectWillChange` del objeto directo, no de sub-objetos.
- **Fix**: En `init()`, se hace forward de `timer.objectWillChange` → `self.objectWillChange.send()`.
- Sin este forward, el popover no se re-renderiza cuando el timer hace tick.

### Concurrencia Swift
- `SessionViewModel` es `@MainActor`. `AppDelegate` también `@MainActor`.
- `TimerEngine` NO es `@MainActor` pero publica en `.main` via `Timer.publish(every: 1, on: .main, in: .common)`.

### El popover
- Tamaño fijo: 280×400.
- Behavior: `.transient` (se cierra al hacer click fuera).
- Se cierra automáticamente en fullscreen cuando la menubar se oculta (`NSWindow.didResignKeyNotification`).
- Left-click en menubar: toggle popover. Right-click: menú contextual.

### Menú contextual (right-click)
- **Language**: submenú con System / Español / English. Usa `UserDefaults "AppleLanguages"`.
- **Reset All Data**: limpia todas las keys `cadence_*` de UserDefaults. Solo para dev/testing.
- **Quit**: cierra la app.

### Colores
- Definidos como hex strings en `SessionMode`. Extension `Color(hex:)` en `SessionMode.swift`.
- Para fondos de UI: usar `mode.color.opacity(0.15)` — funciona en light y dark mode.
- **No usar** `lightBackground` para fondos de componentes (es para light mode only, deprecated en la práctica).

### Sin assets
- No hay `.xcassets`. No hay imágenes custom. No hay archivos de audio.
- Todo es SF Symbols + colores programáticos + `NSSound.beep()`.

## Info.plist crítico
```
LSUIElement = true              → No aparece en Dock
NSHighResolutionCapable = true  → Soporte Retina
```
Se configuran via `INFOPLIST_KEY_*` en el build settings del `project.yml` de XcodeGen.

## Build

```bash
# Regenerar proyecto tras añadir/mover archivos
xcodegen generate

# Compilar desde terminal
xcodebuild -project Cadence.xcodeproj -scheme Cadence -configuration Debug build

# Abrir en Xcode
open Cadence.xcodeproj
```

## Roadmap v2 (pendiente)

- Intent + outcome logging
- AI ratio semanal
- Focus heatmap (estilo GitHub)
- Focus Shield (auto-DND)
- Ambient mode visual
- Sound profiles por modo
- Context tags (#frontend, #writing)
- Peak hours detection
- Personal records
- Persistencia cross-day para streak real
- Selector de idioma instantáneo (sin reinicio, localización custom)
