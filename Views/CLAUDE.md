# Views/

Todas las vistas SwiftUI de la app. El archivo principal es `PopoverView.swift` que contiene el layout completo + subcomponentes privados.

## PopoverView.swift

Vista principal del popover (280px ancho). Layout vertical:

```
┌─────────────────────────┐
│ Header (Cadence + 🔥 N) │
├─────────────────────────┤
│ ModeTabsView            │
│ [UndoPillView]          │  ← solo si showUndoModeChange
├─────────────────────────┤
│ TimerRingView           │
│ OverflowBanner ó        │  ← si showOverflowBanner
│ ControlsView            │  ← si no
├─────────────────────────┤
│ [AI Pause button]       │  ← solo si sesión activa y modo ≠ aiWait
├─────────────────────────┤
│ HistoryDotsView         │
├─────────────────────────┤
│ StatsRowView            │
│ [BreakDebt indicator]   │  ← solo si nivel > .ok
└─────────────────────────┘
```

### Subcomponentes (private structs dentro del archivo)

| Struct | Descripción |
|---|---|
| `ControlsView` | Botones Reset / Play-Pause / Skip + IterationCounter |
| `OverflowBannerView` | Banner "Sesión completada" con "+5 min" y "Terminar". Fondo: `mode.color.opacity(0.15)` |
| `IterationCounterView` | Botón "Contar iteración IA" / "N iteraciones" |
| `HistoryDotsView` | 10 dots: últimas 9 sesiones + 1 slot activo + vacíos. Recibe `totalCount` para el texto "hoy, N ses." |
| `StatsRowView` | 3 stats: Foco hoy / Esperas IA / Flow score |
| `StatCell` | Celda individual de stat |
| `UndoPillView` | Píldora "Modo cambiado — deshacer" con icono arrow.uturn.backward |
| `CircleButton` | Botón circular reutilizable (primario 44px, secundario 36px) |
| `PillButtonStyle` | ButtonStyle tipo píldora con fondo semitransparente |

### History Dots — sliding window
- Recibe `sessions` (ya recortado a `.suffix(10)` por el VM) + `totalCount` (count real)
- Muestra `suffix(9)` de sesiones pasadas + 1 slot activo + slots vacíos
- El texto "hoy, N ses." usa `totalCount`, no `sessions.count`

### Localización
Todos los textos visibles usan `NSLocalizedString("key", comment: "")`. Keys definidas en `Resources/{lang}.lproj/Localizable.strings`.

---

## TimerRingView.swift

Anillo circular de progreso SVG-style. Stateless — recibe props.

| Prop | Tipo | Uso |
|---|---|---|
| `progress` | `Double` | 0.0–1.0, llena el anillo clockwise desde las 12 |
| `mode` | `SessionMode` | Color del anillo |
| `timeString` | `String` | Texto central "MM:SS" |
| `isOverflow` | `Bool` | Activa: pulse ring, checkmark verde, texto "completada" |

- Anillo: 120px, línea 5pt, `lineCap: .round`
- Animación: `.linear(duration: 0.4)` por tick
- Overflow: ring exterior pulsante (`.easeInOut 1.2s repeatForever`), checkmark `checkmark.circle.fill` verde, texto localizado "completada"

---

## ModeTabsView.swift

4 tabs horizontales. Cada tab muestra emoji + label localizado.

- Tab activo: fondo `mode.color.opacity(0.15)`, texto en `mode.color`, borde `mode.color.opacity(0.5)`
- Tab inactivo: sin fondo, texto `.secondary`, borde `.primary.opacity(0.1)`
- Al tap: llama `vm.setMode(mode)` — si hay sesión activa, triggerea undo
