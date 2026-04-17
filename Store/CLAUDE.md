# Store/

Persistencia con UserDefaults. Un solo archivo, sin dependencias.

## SettingsStore.swift

Singleton para preferencias de usuario. Actualmente almacena las 4 duraciones de sesión (minutos). La UI para editarlas queda para v2 — por ahora solo accesible via `defaults write com.cadence.app <key> -int <minutos>`.

### Keys
| Key | Default (min) | Modo |
|---|---|---|
| `cadence_duration_deep` | 25 | `.deep` |
| `cadence_duration_aiWait` | 5 | `.aiWait` |
| `cadence_duration_review` | 10 | `.review` |
| `cadence_duration_rest` | 5 | `.rest` |

### API
- `SettingsStore.shared` — singleton.
- `durationSeconds(for: SessionMode) -> Int` — lee minutos de UserDefaults (o default), devuelve segundos.
- `setDurationMinutes(_ minutes: Int, for: SessionMode)` — escribe en UserDefaults.

`SessionMode.duration` llama a este store, así que cambios en UserDefaults se reflejan inmediatamente en nuevas sesiones.

## DayStore.swift

Guarda y carga sesiones del día + streak global.

### Keys de UserDefaults
| Key | Tipo | Contenido |
|---|---|---|
| `cadence_sessions_YYYY-MM-DD` | `Data` (JSON) | Array de `Session` del día |
| `cadence_streak` | `Int` | Streak global (deep sessions completadas hoy) |

### Métodos
| Método | Qué hace |
|---|---|
| `loadToday() -> DayRecord` | Lee sesiones del día actual + streak. Retorna `DayRecord` vacío si no hay datos |
| `save(sessions:streak:)` | Serializa sesiones a JSON y guarda ambas keys |

### Notas
- Una key por día → los datos de días anteriores quedan en UserDefaults indefinidamente
- No hay migración ni limpieza automática de datos viejos
- El formato de fecha es `yyyy-MM-dd` (ej. `cadence_sessions_2026-04-15`)
- El "Reset All Data" en el menú contextual limpia todas las keys con prefijo `cadence_`
- v2 podría migrar a CoreData si se necesitan queries complejas (heatmap, analytics)
