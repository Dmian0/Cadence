# Views/

Todas las vistas SwiftUI de la app. El archivo principal es `PopoverView.swift` que contiene el layout completo + subcomponentes privados.

## PopoverView.swift

Vista principal del popover (280px ancho). Layout vertical:

```
┌─────────────────────────┐
│ Header (Cadence + 🔥 N) │
├─────────────────────────┤
│ ModeTabsView            │
│ [SubSessionChoiceBanner]│  ← solo si showSubSessionChoice
├─────────────────────────┤
│ TimerRingView           │
│ OverflowBanner ó        │  ← si showOverflowBanner (contextual)
│ ControlsView            │  ← si no (oculto también si banner elección visible)
├─────────────────────────┤
│ [Quick-action button]   │  ← contextual según modo y estado sub-sesión
├─────────────────────────┤
│ HistoryDotsView         │
├─────────────────────────┤
│ StatsRowView            │
│ [BreakDebt indicator]   │  ← solo si nivel > .ok
└─────────────────────────┘
```

### Quick-action buttons (contextuales)
- Deep Work activo → "Esperando respuesta IA — pausar" (verde, `activateAIWait()`)
- AI Wait sub-sesión → "Llegó la respuesta — revisar" (ámbar, `activateReview()`)
- Review sub-sesión → "Volver a Deep Work" (púrpura, `returnToDeepWork()`)
- Solo visibles con sesión activa y sin banner de elección ni overflow visible.
- Todos usan estilo dashed-border con el color del modo destino.

### Subcomponentes (private structs dentro del archivo)

| Struct | Descripción |
|---|---|
| `SubSessionChoiceBanner` | Banner al cambiar tab con sesión activa: info sesión actual + "Continuar como sub-sesión" (prominente) + "nueva sesión independiente" (link) |
| `ControlsView` | Botones Reset / Play-Pause / Skip + IterationCounter |
| `OverflowBannerView` | Banner contextual según `vm.overflowContext`: normal ("+5 min" / "Terminar"), AI Wait sub ("+5 min" / "Llegó la respuesta"), Review sub ("+5 min" / "Terminar review" / "Volver a Deep Work") |
| `IterationCounterView` | Botón "Contar iteración IA" / "N iteraciones" |
| `HistoryDotsView` | 10 dots: últimas 9 sesiones + 1 slot activo + vacíos. Sub-sesiones: 7px, padres: 10px. Incompletas: opacity 0.35 |
| `StatsRowView` | 3 stats: Foco hoy / Esperas IA / Flow score |
| `StatCell` | Celda individual de stat |
| `CircleButton` | Botón circular reutilizable (primario 44px, secundario 36px) |
| `PillButtonStyle` | ButtonStyle tipo píldora con fondo semitransparente |

### History Dots — sliding window
- Recibe `sessions` (ya recortado a `.suffix(10)` por el VM) + `totalCount` (count real)
- Muestra `suffix(9)` de sesiones pasadas + 1 slot activo + slots vacíos
- Tamaño de dot: 10px para padre/independiente, 7px para sub-sesión (`isSubSession`)
- Opacity: 1.0 si completada, 0.35 si incompleta
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
- Al tap: llama `vm.setMode(mode)` — si hay sesión activa, muestra banner de elección sub-sesión
