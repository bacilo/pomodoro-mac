# PomodoroApp Bug Fixes

## What This Is

A macOS menubar Pomodoro timer app built with SwiftUI. The app is fully functional but has two UX bugs that affect daily workflow: it doesn't detect overnight date changes while running, and the popover loses its anchor on screens with auto-hiding menu bars.

## Core Value

The timer must reliably track work sessions and automatically reset for each new day without manual intervention.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. Inferred from existing codebase. -->

- ✓ User can start/pause/skip pomodoro timer — existing
- ✓ Timer shows work/break states with durations — existing
- ✓ Completed sessions recorded in statistics — existing
- ✓ Daily slots track work breakdown — existing
- ✓ Templates allow quick slot setup — existing
- ✓ History preserves past day data — existing
- ✓ Notifications alert on timer completion — existing
- ✓ Sounds play on timer events — existing
- ✓ Settings persist across sessions — existing

### Active

<!-- Current scope. Building toward these. -->

- [ ] App detects new calendar day while running and reinitializes (archives yesterday, shows fresh state, prompts for template if applicable)
- [ ] Popover remains anchored to status item when menu bar auto-hides on multi-monitor setups

### Out of Scope

- Cloud sync — single-device app by design
- iOS/watchOS versions — macOS only
- Major refactoring — minimal changes to fix bugs

## Context

**Technical environment:**
- macOS 13.0+ menubar app (LSUIElement)
- MVVM architecture with SwiftUI views and AppKit integration
- SlotManager has `checkForNewDay()` called from MenuBarView.onAppear and AppDelegate.applicationDidFinishLaunching
- Popover anchored to NSStatusItem button via `show(relativeTo:of:preferredEdge:)`

**Current new day behavior:**
- `checkForNewDay()` exists but only runs on app launch and popover open
- If app stays open overnight, no date check occurs until user interaction
- User must manually quit/reopen to get fresh day state

**Current popover behavior:**
- Popover created in AppDelegate and shown relative to status item button
- On screens with auto-hiding menu bar, the status item position changes when menu bar hides
- Popover loses anchor and jumps to fallback position (top-left corner)

**Prior fix attempts:**
- User has tried to fix both issues multiple times without success
- Suggests non-obvious root causes or edge cases

## Constraints

- **Minimal changes**: Fix bugs without major refactoring
- **Existing architecture**: Work within MVVM + AppKit/SwiftUI hybrid
- **macOS 13.0+**: Target deployment stays the same

## Key Decisions

<!-- Decisions that constrain future work. Add throughout project lifecycle. -->

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Silent reset on new day | User prefers no modal/alert, just fresh state | — Pending |
| Archive yesterday's data | Preserve history before reset | — Pending |

---
*Last updated: 2026-02-12 after initialization*
