# Roadmap: PomodoroApp Bug Fixes

## Overview

Two independent bug fixes for a functional macOS menubar Pomodoro timer: automatic day detection for overnight usage, and stable popover positioning on multi-monitor setups with auto-hiding menubars. Both fixes integrate into existing MVVM architecture without major refactoring.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Day Detection** - App automatically detects new calendar days while running ✓ 2026-02-12
- [ ] **Phase 2: Popover Positioning** - Popover remains stably anchored to menubar status item

## Phase Details

### Phase 1: Day Detection
**Goal**: App automatically detects calendar day changes without requiring user interaction, preserving data integrity across overnight usage and sleep/wake cycles.

**Depends on**: Nothing (first phase)

**Requirements**: DAY-01, DAY-02, DAY-03, DAY-04, DAY-05

**Success Criteria** (what must be TRUE):
  1. User leaves app running overnight and wakes to fresh day state (today's date shown, yesterday archived)
  2. User closes Mac lid at night, opens next morning, and sees correct date without manual intervention
  3. User travels to different timezone and app updates day boundary to local time
  4. User works through DST transition (spring forward or fall back) and app correctly handles midnight timing

**Plans:** 1 plan

Plans:
- [x] 01-01-PLAN.md — Triple-redundancy day detection (NSCalendarDayChanged + wake notification + midnight timer + timezone change) ✓

### Phase 2: Popover Positioning
**Goal**: Popover consistently positions near menubar status item regardless of display configuration, menubar auto-hide state, or dynamic content updates.

**Depends on**: Phase 1

**Requirements**: POP-01, POP-02, POP-03, POP-04

**Success Criteria** (what must be TRUE):
  1. User enables auto-hiding menubar and popover remains anchored when menubar hides/shows
  2. User moves app between monitors and popover appears correctly positioned on active screen
  3. User keeps popover open while timer runs and popover doesn't jump or jitter during status item updates
  4. If positioning fails for any reason, popover dismisses cleanly rather than appearing at screen corner

**Plans:** 1 plan

Plans:
- [ ] 02-01-PLAN.md — Fixed-width status item, timer suspension, coordinate caching, and graceful dismissal

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Day Detection | 1/1 | Complete | 2026-02-12 |
| 2. Popover Positioning | 0/1 | Ready | - |
