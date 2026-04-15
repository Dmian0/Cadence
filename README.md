# Cadence

A macOS menubar app for focused work in the AI era. Cadence reimagines the Pomodoro technique
for a workflow where the bottleneck constantly shifts between you and the machine.

> Built with SwiftUI + AppKit. macOS 13.0+.

---

## The problem with classic Pomodoro

Traditional Pomodoro assumes *you* are always the bottleneck. You work, you rest, repeat.
But modern AI-assisted work has a different rhythm — you think, you prompt, you wait, you review.
That waiting time is neither work nor rest, and classic timers have no model for it.

Cadence solves this with 4 session modes instead of 2.

---

## Session modes

| Mode | Duration | Purpose |
|------|----------|---------|
| ⚡ Deep work | 25 min | Full focus. No interruptions. |
| ⏳ AI wait | Adaptive | You sent a prompt. Timer captures the wait. |
| 👁 Review | 10 min | Reading and evaluating AI output. |
| ☁ Break | 5 min | Real rest. App suggests breaks based on debt. |

Each mode has a distinct color, score weight, and contributes differently to your daily stats.

---

## Features

### AI Pause button
A dashed green button in the panel that appears whenever you're in a work session.
One tap switches to AI Wait mode and starts timing the wait — capturing the exact moment
you send a prompt without breaking your flow.

### Iteration counter
A subtle tap counter during active sessions. Each tap = one prompt sent to an AI.
A high number (8+) in a single session often signals the problem isn't well defined.

### Gentle overflow
When a timer ends, there's no alarm. The ring pulses softly and two options appear:
**+5 min** (extend) or **Finish** (mark complete). No anxiety, no hard stops.

### Break debt
Tracks consecutive work sessions without a real break. The panel shows a warning
after 3 sessions and a red indicator after 5. The menubar icon reflects the level.

### Flow score
A 0–100 daily score weighted by session quality, not just volume.
8 completed Deep Work sessions = 100. AI Wait contributes less than Review,
which contributes less than Deep Work. Hard to game.

### Session history dots
A row of 10 colored squares showing your last 10 sessions.
Color = mode. Faded = incomplete (skipped). The active slot pulses.

### Daily stats
- **Foco hoy** — total time in Deep Work + Review
- **Esperas IA** — total time in AI Wait
- **Completadas** — % of sessions that reached natural end

---

## Project structure

```
Cadence/
├── CadenceApp.swift          Entry point
├── AppDelegate.swift         NSStatusItem + NSPopover
├── Info.plist                LSUIElement=true (menubar-only)
├── project.yml               XcodeGen config
├── Models/
│   ├── SessionMode.swift     4 modes, colors, weights, durations
│   └── Session.swift         Session struct + DayRecord
├── Engine/
│   └── TimerEngine.swift     Combine-based countdown
├── ViewModel/
│   └── SessionViewModel.swift  App state, orchestrates everything
├── Views/
│   ├── PopoverView.swift     Main panel (280px)
│   ├── TimerRingView.swift   Circular progress ring
│   └── ModeTabsView.swift    Mode selector
└── Store/
    └── DayStore.swift        UserDefaults persistence (per-day key)
```

---

## Setup

### Requirements
- macOS 13.0+
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### Install XcodeGen
```bash
brew install xcodegen
```

### Clone and run
```bash
git clone https://github.com/Dmian0/Cadence.git
cd Cadence
xcodegen generate
open Cadence.xcodeproj
```

Press ⌘R in Xcode. The app appears in your menubar — no Dock icon.

---

## Roadmap

### v1 — current
- [x] 4 session modes with distinct colors and weights
- [x] Menubar icon with live timer
- [x] Expandable popover panel
- [x] AI Pause quick button
- [x] Iteration counter
- [x] Gentle overflow (+5 min, no alarm)
- [x] Break debt indicator
- [x] Flow score
- [x] Session history dots
- [x] Daily stats (focus time, AI wait, completion rate)
- [x] UserDefaults persistence per day

### v2 — planned
- [ ] Intent + outcome logging ("what are you working on?" / "did you finish it?")
- [ ] Weekly AI ratio (% deep work vs AI wait trend)
- [ ] Focus heatmap (GitHub-style contributions grid)
- [ ] Focus Shield (auto-enable macOS Do Not Disturb during Deep Work)
- [ ] Ambient mode (soft visual instead of countdown)
- [ ] Sound profiles per mode
- [ ] Context tags (#frontend, #writing, #design)
- [ ] Peak hours detection (learns your best focus window)
- [ ] Personal records (only vs yourself, never others)
- [ ] Cross-day streak tracking

---

## Tech decisions

- **Menubar only** — `LSUIElement = true` in Info.plist, `.accessory` activation policy
- **No CoreData** — UserDefaults is sufficient for v1's per-day flat data
- **Combine timer** — `Timer.publish` over `Timer.scheduledTimer` for clean lifecycle management
- **XcodeGen** — `project.yml` is versioned; `.xcodeproj` is gitignored
- **No external dependencies** — pure Apple frameworks only (SwiftUI, AppKit, Combine)

---

## Development notes

`FEATURES.md` contains the full behavioral spec for every feature — exact formulas,
visibility conditions, color values, and v2 descriptions. Reference it when implementing
new features or debugging unexpected behavior.

---

*Cadence — work with the machine, not against its rhythm.*
