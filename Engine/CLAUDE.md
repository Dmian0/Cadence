# Engine/

Motor del timer. Un solo archivo, sin dependencias externas.

## TimerEngine.swift

`ObservableObject` que maneja el countdown de 1Hz via Combine.

**No es `@MainActor`** — publica en main thread via `Timer.publish(every: 1, on: .main, in: .common)`.

### Estado publicado
| Propiedad | Tipo | Descripción |
|---|---|---|
| `secondsRemaining` | `Int` | Segundos restantes, decrementa cada tick |
| `isRunning` | `Bool` | Si el timer está activo |
| `isOverflow` | `Bool` | Timer llegó a cero, modo "gentle overflow" |

### Métodos públicos
| Método | Qué hace |
|---|---|
| `load(seconds:)` | Para el timer, setea duración total y restante |
| `start()` | Inicia el countdown (guarded, no duplica) |
| `pause()` | Pausa sin resetear |
| `stop()` | Pausa y resetea `secondsRemaining` a `totalSeconds` |
| `reset()` | Alias de `stop()` |
| `extend(by:)` | **Suma** segundos al tiempo restante (`+=`), recalcula `totalSeconds = secondsRemaining` para que el anillo de progreso arranque lleno |

### Propiedades computadas
- `progress: Double` — 0.0 → 1.0, usado por `TimerRingView` para el anillo
- `displayString: String` — formato `MM:SS`

### Evento
- `onNaturalEnd: PassthroughSubject<Void, Never>` — se dispara cuando `secondsRemaining` llega a 0 por primera vez. `SessionViewModel` lo escucha para mostrar el overflow banner.

### Cuidado
- `extend(by:)` usa `+=` para sumar, no `=`. Esto fue un bug corregido.
- `totalSeconds` se resetea a `secondsRemaining` después de extend para que `progress` sea correcto.
- El timer no dispara inmediatamente al hacer `start()` — hay ~1s de delay antes del primer tick.
