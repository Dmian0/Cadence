# Store/

Persistencia con UserDefaults. Un solo archivo, sin dependencias.

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
