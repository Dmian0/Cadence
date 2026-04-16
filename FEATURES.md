# Cadence — Feature Reference

Este documento describe cada feature de Cadence en detalle.
Es la fuente de verdad para entender qué hace cada parte del sistema y cómo deben comportarse.

---

## Concepto central

Cadence es una app de productividad para macOS tipo Pomodoro, diseñada para el flujo de trabajo
moderno donde la IA (Claude, Cursor, ChatGPT, etc.) participa activamente. El Pomodoro clásico
asume que el usuario es el único cuello de botella. Cadence reconoce que ahora el cuello de botella
alterna entre el usuario y la máquina, y modela eso explícitamente con 4 modos de sesión.

La app vive **solo en la menubar** (no tiene ventana principal ni ícono en el Dock).
El panel se abre como un NSPopover al hacer clic en el ícono de la menubar.

---

## Arquitectura

```
CadenceApp.swift          Entry point (@main), registra AppDelegate
AppDelegate.swift         NSStatusItem + NSPopover, bindings de menubar
Models/
  SessionMode.swift       Enum con los 4 modos, colores, duraciones, pesos
  Session.swift           Struct de una sesión individual + DayRecord
Engine/
  TimerEngine.swift       Combine-based countdown, publica segundos restantes
ViewModel/
  SessionViewModel.swift  Estado global de la app, orquesta Timer + Store
Views/
  PopoverView.swift       Panel principal (280px ancho)
  TimerRingView.swift     Anillo de progreso circular animado
  ModeTabsView.swift      Selector de los 4 modos
Store/
  DayStore.swift          Persistencia con UserDefaults, key por fecha
```

---

## Los 4 modos de sesión

### 1. Deep Work (modo: `.deep`)
- **Duración:** 25 minutos
- **Color:** Púrpura `#7F77DD`
- **Score weight:** 1.0 (máximo valor)
- **Propósito:** Trabajo de foco profundo sin interrupciones. Es el modo principal.
- **Comportamiento:** Timer cuenta regresiva. Al llegar a cero activa el Gentle Overflow.
- **Break debt:** Cuenta como sesión de trabajo.

### 2. AI Wait (modo: `.aiWait`)
- **Duración:** 5 minutos (adaptativo — puede resetearse libremente)
- **Color:** Verde teal `#1D9E75`
- **Score weight:** 0.2 (bajo, es tiempo pasivo)
- **Propósito:** El usuario envió un prompt a una IA y está esperando respuesta.
  El timer se activa para que el tiempo de espera no se pierda ni genere ansiedad.
- **Comportamiento especial:** Hay un botón de acceso rápido en el panel ("Esperando respuesta IA — pausar")
  que aparece cuando el modo activo NO es `.aiWait`. Al pulsarlo cambia al modo AI Wait
  automáticamente e inicia la sesión. Esto permite capturar el momento exacto en que
  se envía el prompt.
- **Break debt:** Cuenta como sesión de trabajo (aunque con peso bajo).
- **Iteration counter:** El botón "+ iteración" es especialmente relevante en este modo
  para contar cuántos prompts se han enviado en la sesión.

### 3. Review (modo: `.review`)
- **Duración:** 10 minutos
- **Color:** Ámbar `#EF9F27`
- **Score weight:** 0.5 (medio — es trabajo activo pero menos intenso)
- **Propósito:** Leer y evaluar el output que devolvió la IA. Requiere concentración
  pero es menos cognitivamente demandante que Deep Work.
- **Comportamiento:** Igual que Deep Work pero más corto.
- **Break debt:** Cuenta como sesión de trabajo.

### 4. Break (modo: `.rest`)
- **Duración:** 5 minutos
- **Color:** Azul `#378ADD`
- **Score weight:** 0.0 (no contribuye al score — es descanso)
- **Propósito:** Descanso real. Levantarse, estirarse, agua.
- **Comportamiento especial:** Al completarse, cambia automáticamente al modo Deep Work
  sin necesidad de acción del usuario.
- **Break debt:** Resetea el contador de break debt.

---

## Features v1

### Timer Ring
- Anillo circular SVG-style con progreso de 0 a 1 en sentido horario desde las 12.
- El color del anillo cambia según el modo activo.
- El grosor de la línea es 5pt.
- Muestra el tiempo restante en formato `MM:SS` en el centro con fuente monospaced.
- Animación suave (0.4s linear) en cada tick.

### Menubar Icon
- Muestra el SF Symbol del modo actual + tiempo restante en texto.
- Ejemplo: `⚡ 22:14` durante Deep Work, `⏳ 04:33` durante AI Wait.
- El color del símbolo refleja el modo activo usando palette colors.
- Click izquierdo: abre/cierra el popover.
- Click derecho: muestra menú contextual con "Quit".

### Mode Tabs
- 4 tabs horizontales en la parte superior del panel.
- Cada tab muestra emoji + label corto.
- El tab activo tiene fondo de color claro (lightBackground del modo) y borde del color del modo.
- Cambiar de tab mientras hay sesión activa termina la sesión actual como incompleta
  e inicia el setup del nuevo modo (sin iniciar el timer automáticamente).

### Play / Pause / Reset / Skip Controls
- **Play/Pause (botón primario, 44px):** Inicia la sesión si no hay ninguna activa.
  Si hay sesión activa, pausa/reanuda el timer.
- **Reset (botón secundario izquierdo, 36px):** Para el timer y lo devuelve al inicio
  de la duración del modo actual. No termina la sesión en el registro.
- **Skip (botón secundario derecho, 36px):** Termina la sesión como incompleta
  y avanza al siguiente modo lógico (Deep Work → Break, cualquier otro → Deep Work).

### Quick-Action Buttons (Botones de acceso rápido)
Tres botones contextuales con borde punteado que crean el ciclo de trabajo con IA:

```
[Deep Work]   →  "Esperando respuesta IA — pausar"  →  [AI Wait sub-sesión]
[AI Wait]     →  "Llegó la respuesta — revisar"      →  [Review sub-sesión]
[Review]      →  "Volver a Deep Work"                →  [Deep Work] (reanuda padre)
```

- **"Esperando respuesta IA — pausar"** (verde): Visible en Deep Work con sesión activa.
  Suspende la sesión padre y crea una sub-sesión AI Wait.
- **"Llegó la respuesta — revisar"** (ámbar): Visible en AI Wait con padre suspendido.
  Completa AI Wait, inicia Review sub-sesión.
- **"Volver a Deep Work"** (púrpura): Visible en Review con padre suspendido.
  Completa Review, reanuda la sesión padre con el tiempo exacto donde quedó.
- Los tres desaparecen cuando no hay sesión activa o cuando hay un banner visible.

### Session Hierarchy (Sub-sesiones)
- **Sesión padre**: iniciada manualmente desde un tab. Dot grande (10px) en historial.
- **Sub-sesión**: iniciada desde botón de acceso rápido. Dot pequeño (7px) en historial.
  La sesión padre se suspende en background con su tiempo restante guardado.
- Al regresar a Deep Work desde Review, se reanuda la sesión padre original.
- Sub-sesiones se almacenan dentro del array `subSessions` del padre.
- Solo sesiones padre cuentan para el Flow Score.

### Sub-Session Choice Banner
- Al cambiar de tab mientras hay sesión activa, aparece un banner inline (no modal):
  - **"Continuar como sub-sesión"** (botón prominente): Suspende sesión actual, inicia sub-sesión.
  - **"nueva sesión independiente"** (link): Termina sesión actual como completada, inicia nueva independiente.
- Si el usuario cierra el popover sin elegir, la sesión original continúa corriendo.

### Iteration Counter
- Botón de texto pequeño debajo de los controles principales.
- Visible cuando: hay sesión activa Y el modo no es `.rest`.
- Texto: "Contar iteración IA" (si count = 0) o "N iteraciones" (si count > 0).
- Cada tap incrementa el contador en 1.
- El contador se guarda en la sesión al terminarla.
- Se resetea al cambiar de modo o iniciar nueva sesión.
- Propósito: un número alto de iteraciones (8+) en una sola sesión puede indicar
  que el prompt no está bien definido.

### Gentle Overflow
- Cuando el timer llega a 0 en un modo de trabajo (no `.rest`), NO suena una alarma fuerte.
- En cambio:
  1. El timer se pausa en 00:00.
  2. El anillo cambia a opacidad reducida y pulsa suavemente.
  3. El texto central muestra "continúa..." en lugar del tiempo.
  4. En el panel aparece un banner contextual según el tipo de sesión:
     - **Sesión normal:** "+5 min" / "Terminar"
     - **AI Wait sub-sesión:** "+5 min" / "Llegó la respuesta — revisar"
     - **Review sub-sesión:** "+5 min" / "Terminar review" / "Volver a Deep Work"
- **+ 5 min** siempre extiende la sesión actual (no crea nueva ni resetea timer).
- Si los +5 min expiran, el banner vuelve a aparecer (repetible N veces).
- Al terminar ("Terminar"), el timer se resetea a la duración original del modo.
- El banner tiene el fondo `mode.color.opacity(0.15)`.
- Solo un `NSSound.beep()` como notificación (v2 reemplaza con sonido personalizado).

### Break Debt
- Contador interno de sesiones de trabajo consecutivas sin un Break completado.
- Se calcula mirando las sesiones de `todaySessions` en orden inverso hasta encontrar
  un `.rest` completado (o el inicio del día).
- Niveles:
  - **0–2 sesiones:** `.ok` — no se muestra nada en el panel.
  - **3–4 sesiones:** `.warning` — aparece indicador ámbar "Toma un break pronto".
  - **5+ sesiones:** `.critical` — aparece indicador rojo "Break necesario".
- El indicador aparece debajo de las stats en el panel.
- El ícono del menubar puede cambiar de color para reflejar el nivel (v2).

### Flow Score
- Número entero 0–100 que representa la calidad del día de trabajo.
- Solo sesiones padre/independientes cuentan (no sub-sesiones directamente).
- Fórmula: `min(100, Int((sumScores / 8.0) * 100))`
  donde `sumScores` = suma de `scoreContribution` de cada sesión padre del día.
- `scoreContribution`:
  - Sesión completada: usa el `scoreWeight` del modo (deep=1.0, review=0.5, aiWait=0.2, rest=0.0)
  - Sesión incompleta: `scoreWeight * 0.3`
- Referencia: 8 Deep Work completados = score 100.
- Se muestra en las stats del panel como "Score" (v2 — en v1 aparece implícitamente en el % de completadas).

### History Dots
- Fila de 10 cuadrados pequeños (10x10px, border-radius 3px) debajo de los controles.
- Muestra las últimas 10 sesiones del día (o menos si hay menos).
- Color según el modo de la sesión.
- Opacidad reducida (0.4) si la sesión fue incompleta (skipped).
- El slot actual (posición `sessions.count`) muestra el color del modo activo con borde.
- Los slots vacíos son gris muy claro.
- Debajo a la derecha: "hoy, N ses." con el conteo total.

### Streak
- Cuenta las sesiones Deep Work completadas en el día actual.
- Se muestra en el header del panel con emoji 🔥.
- Formato: "🔥 N racha"
- v2: el streak se extiende a días consecutivos con al menos 1 Deep Work completado.

### Stats Row
- Tres celdas en la parte inferior del panel, separadas por divisores verticales.
- **Foco hoy:** Suma del tiempo real en sesiones `.deep` y `.review` del día.
  Formato: "3h 12m" o "45m".
- **Esperas IA:** Suma del tiempo real en sesiones `.aiWait` del día.
  Formato igual.
- **Completadas:** Porcentaje de sesiones que llegaron a su fin natural.
  Fórmula: `(sesiones completadas / total sesiones) * 100`.

### Persistencia
- `DayStore` guarda y carga usando `UserDefaults`.
- Key de sesiones: `cadence_sessions_YYYY-MM-DD` (una key por día).
- Key de streak: `cadence_streak` (global por ahora, v2 lo extiende).
- Los datos del día se guardan cada vez que termina una sesión.
- Al lanzar la app se cargan automáticamente las sesiones del día actual.

---

## Features v2 (no implementar aún)

Estas features están diseñadas pero pendientes para la siguiente versión.
No modificar la arquitectura actual para acomodarlas — se agregarán incrementalmente.

### Intent + Outcome Logging
- Al iniciar una sesión Deep Work: sheet/prompt "¿Qué vas a hacer?"
- Al terminar: "¿Lo completaste?" con opciones Sí / Parcial / No.
- Los datos se guardan en la sesión y afectan el score.

### AI Ratio Semanal
- Vista de analíticas con breakdown porcentual de la semana:
  % Deep Work vs % AI Wait vs % Review vs % Break.
- Si el AI Wait sube semana a semana puede indicar prompting ineficiente.

### Focus Heatmap
- Cuadrícula estilo GitHub contributions.
- Cada día = un cuadro con color según el flow score del día.
- 52 semanas visibles (un año).

### Focus Shield
- Al entrar en Deep Work activa automáticamente macOS Focus/No Molestar.
- Al terminar lo desactiva.
- Requiere el entitlement `com.apple.focus` y permiso del usuario en onboarding.

### Ambient Mode
- Opción para reemplazar el countdown numérico con un visual abstracto
  que cambia lentamente (temperatura de color, forma que se expande).
- Reduce la ansiedad por el tiempo en usuarios sensibles.

### Sound Profiles
- Cada modo tiene un perfil de sonido distinto:
  - Deep Work: brown noise o silencio.
  - AI Wait: sonido suave de "enviado" al activarse.
  - Break: sonido que rompe el modo trabajo (más alegre/diferente).
- Audio generado con AVFoundation, sin assets externos.

### Context Tags
- Tag rápido al iniciar sesión: #frontend, #diseño, #writing, etc.
- Tags personalizables.
- Las analíticas se filtran por tag para ver dónde va realmente el tiempo.

### Peak Hours
- Después de ~14 días de datos detecta en qué franja horaria el usuario
  completa más sesiones sin interrumpir.
- Muestra: "Tu ventana de foco: 9am–12pm".

### Personal Records
- Solo compara el usuario consigo mismo, nunca con otros.
- Ejemplos: "Nuevo récord: 4h 20m de deep work en un día", "7 sesiones completadas seguidas".
- Notificación local sutil al superar un record.

### Streak Cross-Day
- El streak actual solo cuenta sesiones del día.
- v2: contar días consecutivos con al menos 1 Deep Work completado.
- Requiere guardar la fecha del último día con sesión completada.

---

## Decisiones de diseño importantes

1. **Sin Dock icon:** `LSUIElement = true` en Info.plist. La app es solo menubar.
2. **Sin ventana principal:** `NSApp.setActivationPolicy(.accessory)` en AppDelegate.
3. **Popover transient:** Se cierra al hacer clic fuera. Behavior = `.transient`.
4. **No usar Timer.scheduledTimer básico:** El TimerEngine usa Combine's `Timer.publish`
   para mejor control del ciclo de vida y cancelación limpia.
5. **@MainActor en ViewModel:** Todas las actualizaciones de UI en el main thread.
6. **UserDefaults sobre CoreData:** La app guarda datos simples por día.
   CoreData sería overkill para v1. Se migrará si v2 necesita queries complejas.
7. **Ancho del panel fijo en 280px:** Calculado para que los 4 mode tabs quepan
   cómodamente y la información sea legible sin ser invasiva.
