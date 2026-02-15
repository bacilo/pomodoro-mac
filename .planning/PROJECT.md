# PomodoroApp

## What This Is

A macOS menubar Pomodoro timer app built with SwiftUI. Features work/break session tracking, daily slot management with templates, statistics, and automatic day detection with stable popover positioning on multi-monitor setups.

## Core Value

The timer must reliably track work sessions and automatically reset for each new day without manual intervention.

## Requirements

### Validated

- ✓ User can start/pause/skip pomodoro timer — existing
- ✓ Timer shows work/break states with durations — existing
- ✓ Completed sessions recorded in statistics — existing
- ✓ Daily slots track work breakdown — existing
- ✓ Templates allow quick slot setup — existing
- ✓ History preserves past day data — existing
- ✓ Notifications alert on timer completion — existing
- ✓ Sounds play on timer events — existing
- ✓ Settings persist across sessions — existing
- ✓ App detects new calendar day while running and reinitializes — v1.0
- ✓ Popover remains anchored to status item on multi-monitor setups — v1.0 (2/3 screens)

### Active

None yet — awaiting next milestone.

### Out of Scope

- Cloud sync — single-device app by design
- iOS/watchOS versions — macOS only
- Smooth animated popover transitions — deferred from v1.0
- Remember preferred screen for popover — deferred from v1.0

## Context

**Technical environment:**
- macOS 13.0+ menubar app (LSUIElement)
- Swift 5.9+, SwiftUI with AppKit integration
- MVVM architecture

**Current state (post v1.0):**
- Day detection: Triple-redundancy system (NSCalendarDayChanged + wake + midnight timer + timezone change) in SlotManager
- Popover: Fixed-width status item, timer suspension during display, display change observer, graceful dismissal
- Known limitation: Popover positioning edge case on third screen in complex multi-monitor setups

## Constraints

- **Existing architecture**: Work within MVVM + AppKit/SwiftUI hybrid
- **macOS 13.0+**: Target deployment stays the same

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Silent reset on new day | User prefers no modal/alert, just fresh state | ✓ Good |
| Archive yesterday's data | Preserve history before reset | ✓ Good |
| Triple-redundancy day detection | Four notification mechanisms ensure reliability | ✓ Good |
| Fixed-width status item | Prevents popover anchor invalidation during updates | ✓ Good |
| Graceful dismissal | Popover closes cleanly rather than jumping to corner | ✓ Good |
| Third screen edge case accepted | Fix works on primary screens, diminishing returns on edge case | ✓ Good |

## Milestones

| Version | Description | Status |
|---------|-------------|--------|
| v1.0 | Bug fixes (day detection, popover positioning) | ✓ Shipped 2026-02-15 |

---
*Last updated: 2026-02-15 after v1.0 milestone archive*
