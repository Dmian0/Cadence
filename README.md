# Cadence — macOS Pomodoro para la era IA

## Setup en Xcode

1. **Nuevo proyecto**
   - File → New → Project → macOS → App
   - Product Name: `Cadence`
   - Interface: SwiftUI
   - Language: Swift
   - Deployment Target: macOS 13.0+

2. **Estructura de archivos**
   Crea los grupos en el Project Navigator y añade los archivos:
   ```
   Cadence/
   ├── CadenceApp.swift
   ├── AppDelegate.swift
   ├── Models/
   │   ├── SessionMode.swift
   │   └── Session.swift
   ├── Engine/
   │   └── TimerEngine.swift
   ├── ViewModel/
   │   └── SessionViewModel.swift
   ├── Views/
   │   ├── PopoverView.swift
   │   ├── TimerRingView.swift
   │   └── ModeTabsView.swift
   └── Store/
       └── DayStore.swift
   ```

3. **Info.plist — configuración crítica**
   Añade estas dos keys para que sea una app de menubar pura (sin ícono en Dock):
   ```xml
   <key>LSUIElement</key>
   <true/>
   <key>NSHighResolutionCapable</key>
   <true/>
   ```

4. **Capabilities**
   No se necesitan capabilities especiales para v1.
   - v2 (Focus Shield): añadir `Focus` en Signing & Capabilities

5. **Build & Run**
   ⌘R — el ícono aparece en la menubar, no en el Dock.

---

## Roadmap

### v1 (este release)
- [x] 4 modos: Deep Work / AI Wait / Review / Break
- [x] Menubar icon con timer en tiempo real
- [x] Panel expandible con ring de progreso
- [x] Iteration counter
- [x] Gentle overflow (+5 min sin alarma)
- [x] Break debt indicator
- [x] Flow score ponderado
- [x] Historial del día (dots de colores)
- [x] Streak de sesiones completadas
- [x] Persistencia con UserDefaults

### v2
- [ ] Intent + outcome logging (¿qué vas a hacer? / ¿lo completaste?)
- [ ] AI ratio semanal (% deep work vs AI wait)
- [ ] Focus heatmap (estilo GitHub contributions)
- [ ] Focus Shield (auto-activar macOS Focus/DND)
- [ ] Ambient mode (visual suave en lugar de countdown)
- [ ] Sound profiles por modo
- [ ] Context tags (#frontend, #writing…)
- [ ] Peak hours (aprende tu ventana de foco)
- [ ] Personal records
- [ ] Persistencia cross-day para streak real
