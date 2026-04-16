<div align="center">

# Cadence

**A macOS menubar timer for focused work in the AI era.**

Reimagines the Pomodoro technique for workflows where the bottleneck
constantly shifts between you and the machine.

`SwiftUI` `AppKit` `Combine` `macOS 13.0+` `v0.1.0-beta`

---

</div>

## Why not classic Pomodoro?

Traditional Pomodoro assumes **you** are always the bottleneck. You work, you rest, repeat.

But AI-assisted work has a different rhythm:

```
you think  -->  you prompt  -->  you wait  -->  you review  -->  repeat
```

That waiting time is neither work nor rest. Classic timers have no model for it.
Cadence solves this with **4 session modes** and a **sub-session hierarchy** that captures the full AI workflow cycle without losing your place.

---

## Session Modes

| | Mode | Duration | Score Weight | Purpose |
|:---:|------|:--------:|:----------:|---------|
| `#7F77DD` | **Deep Work** | 25 min | 1.0 | Full focus. No interruptions. |
| `#1D9E75` | **AI Wait** | 5 min | 0.2 | You sent a prompt. Timer captures the wait. |
| `#EF9F27` | **Review** | 10 min | 0.5 | Reading and evaluating AI output. |
| `#378ADD` | **Break** | 5 min | 0.0 | Real rest. Suggested based on break debt. |

---

## Core Features

### Sub-Session Hierarchy

Sessions flow naturally through the AI work cycle without losing context:

```
Deep Work (parent)
   |
   |--- "Waiting for AI - pause"  --->  AI Wait (sub-session)
   |                                        |
   |                                        |--- "Response arrived"  --->  Review (sub-session)
   |                                                                          |
   |<--- "Back to Deep Work" (resumes with exact remaining time) -------------|
```

The parent session **suspends** with its remaining time preserved. When you return, the timer picks up exactly where you left off. Sub-sessions are stored inside the parent — your history stays clean.

When switching modes via tabs during an active session, a **choice banner** appears:
- **Continue as sub-session** — suspends current, starts child
- **New independent session** — ends current, starts fresh

---

### Gentle Overflow

When a timer ends, there's no alarm. The ring pulses softly and contextual options appear:

| Context | Options |
|---------|---------|
| Normal session | **+5 min** &middot; **Finish** |
| AI Wait sub-session | **+5 min** &middot; **Response arrived — review** |
| Review sub-session | **+5 min** &middot; **Finish review** &middot; **Back to Deep Work** |

Extending always adds to the current session. If those 5 minutes expire, the banner reappears. Repeat as needed. When you finish, the timer resets to the mode's original duration.

---

### Quick-Action Buttons

Three dashed-border buttons that appear contextually during active sessions:

| When in | Button | Action |
|---------|--------|--------|
| Deep Work | *"Waiting for AI — pause"* | Suspend parent, start AI Wait |
| AI Wait (sub) | *"Response arrived — review"* | Complete AI Wait, start Review |
| Review (sub) | *"Back to Deep Work"* | Complete Review, resume parent |

---

### Flow Score

A **0-100 daily score** weighted by session quality, not just volume. Only parent sessions count — sub-sessions contribute through their parent.

```
8 completed Deep Work sessions = 100 points
Review contributes half. AI Wait one-fifth.
Incomplete sessions count at 30% weight.
```

---

### More Features

| Feature | Description |
|---------|-------------|
| **Break debt** | Tracks consecutive work sessions without rest. Warning at 3, critical at 5+. |
| **Iteration counter** | Tap counter during sessions. High count (8+) suggests the prompt needs work. |
| **History dots** | 10 colored squares showing recent sessions. Sub-sessions are smaller. Faded = incomplete. |
| **Daily stats** | Focus time (Deep + Review), AI wait time, Flow score. |
| **Streak** | Completed Deep Work sessions today. |
| **Menubar icon** | SF Symbol + live timer. Left-click: panel. Right-click: language, reset, quit. |
| **Localization** | Spanish and English. Switch from the context menu. |

---

## Project Structure

```
Cadence/
|-- CadenceApp.swift              Entry point (@main)
|-- AppDelegate.swift             NSStatusItem + NSPopover + context menu
|-- project.yml                   XcodeGen config
|
|-- Models/
|   |-- SessionMode.swift         4 modes: colors, weights, durations, symbols
|   +-- Session.swift             Session struct (with sub-session hierarchy) + DayRecord
|
|-- Engine/
|   +-- TimerEngine.swift         Combine-based 1Hz countdown, overflow, extend
|
|-- ViewModel/
|   +-- SessionViewModel.swift    App brain: timer, sessions, sub-sessions, overflow, stats
|
|-- Views/
|   |-- PopoverView.swift         Main panel (280px) + all sub-components
|   |-- TimerRingView.swift       Circular progress ring with overflow pulse
|   +-- ModeTabsView.swift        Horizontal mode selector
|
|-- Store/
|   +-- DayStore.swift            UserDefaults persistence (JSON per day)
|
+-- Resources/
    |-- es.lproj/Localizable.strings
    +-- en.lproj/Localizable.strings
```

---

## Setup

**Requirements:** macOS 13.0+ &middot; Xcode 15+ &middot; [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```bash
# Install XcodeGen (if needed)
brew install xcodegen

# Clone, generate, open
git clone https://github.com/Dmian0/Cadence.git
cd Cadence
xcodegen generate
open Cadence.xcodeproj
```

Press **Cmd+R** in Xcode. The app appears in your menubar — no Dock icon.

---

## Roadmap

### v0.1.0-beta — current

- [x] 4 session modes with distinct colors and weights
- [x] Sub-session hierarchy (parent/child with suspend/resume)
- [x] Quick-action buttons for AI workflow cycle
- [x] Contextual overflow banners per session type
- [x] Sub-session choice banner (sub-session vs independent)
- [x] Menubar icon with live timer
- [x] Gentle overflow (+5 min repeatable, no alarm)
- [x] Break debt indicator (3 levels)
- [x] Flow score (0-100, parent sessions only)
- [x] Session history dots (size varies by session type)
- [x] Iteration counter
- [x] Daily stats (focus time, AI wait, flow score)
- [x] UserDefaults persistence per day
- [x] ES/EN localization

### v2 — planned

- [ ] Intent + outcome logging
- [ ] Weekly AI ratio (deep work vs AI wait trend)
- [ ] Focus heatmap (GitHub-style contributions grid)
- [ ] Focus Shield (auto-enable macOS Do Not Disturb)
- [ ] Ambient mode (soft visual instead of countdown)
- [ ] Sound profiles per mode
- [ ] Context tags (#frontend, #writing, #design)
- [ ] Peak hours detection
- [ ] Personal records (only vs yourself)
- [ ] Cross-day streak tracking

---

## Tech Decisions

| Decision | Rationale |
|----------|-----------|
| Menubar only | `LSUIElement = true`, `.accessory` policy. No Dock icon, no main window. |
| No CoreData | UserDefaults is sufficient for per-day flat data in v1. |
| Combine timer | `Timer.publish` over `Timer.scheduledTimer` for clean lifecycle. |
| XcodeGen | `project.yml` versioned, `.xcodeproj` gitignored. |
| Zero dependencies | Pure Apple frameworks: SwiftUI, AppKit, Combine, Foundation. |

---

<div align="center">

*Work with the machine, not against its rhythm.*

</div>
