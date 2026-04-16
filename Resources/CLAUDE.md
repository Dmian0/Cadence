# Resources/

Archivos de localización. Sin assets, sin imágenes, sin audio.

## Localización (ES/EN)

```
Resources/
├── es.lproj/Localizable.strings   ← Español (default)
└── en.lproj/Localizable.strings   ← English
```

### Cómo usar en código
```swift
NSLocalizedString("key", comment: "")
// Con formato:
String(format: NSLocalizedString("today_sessions", comment: ""), count)
```

### Keys disponibles

| Key | ES | EN | Dónde se usa |
|---|---|---|---|
| `deep_work` | Deep work | Deep work | SessionMode.label, ModeTabsView |
| `ai_wait` | AI wait | AI wait | SessionMode.label |
| `review` | Review | Review | SessionMode.label |
| `break_mode` | Break | Break | SessionMode.label |
| `streak` | racha | streak | PopoverView header |
| `completed_label` | completada | completed | TimerRingView overflow |
| `ai_pause_button` | Esperando respuesta IA — pausar | Waiting for AI — pause | PopoverView |
| `count_iteration` | Contar iteración IA | Count AI iteration | IterationCounterView |
| `iterations_one` | %d iteración | %d iteration | IterationCounterView |
| `iterations_other` | %d iteraciones | %d iterations | IterationCounterView |
| `session_complete` | Sesión completada | Session complete | OverflowBannerView |
| `extend_five` | + 5 min | + 5 min | OverflowBannerView |
| `finish` | Terminar | Finish | OverflowBannerView |
| `mode_changed_undo` | Modo cambiado — deshacer | Mode changed — undo | UndoPillView |
| `today_sessions` | hoy, %d ses. | today, %d ses. | HistoryDotsView |
| `focus_today` | Foco hoy | Focus today | StatsRowView |
| `ai_wait_stat` | Esperas IA | AI wait | StatsRowView |
| `flow_score` | Flow score | Flow score | StatsRowView |
| `on_track` | Al día | On track | BreakDebtLevel |
| `take_break_soon` | Toma un break pronto | Take a break soon | BreakDebtLevel |
| `break_needed` | Break necesario | Break needed | BreakDebtLevel |

### Cambio de idioma
- Right-click en menubar → Language → System / Español / English
- Usa `UserDefaults "AppleLanguages"` para forzar idioma per-app
- Requiere reinicio de la app para aplicar (cache de `NSLocalizedString`)
- `project.yml` tiene `knownRegions: [es, en]`

### Agregar un nuevo string
1. Agregar la key en ambos `Localizable.strings`
2. Usar `NSLocalizedString("nueva_key", comment: "")` en el código
3. Regenerar proyecto: `xcodegen generate`
