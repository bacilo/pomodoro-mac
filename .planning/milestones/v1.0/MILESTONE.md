# Milestone v1.0: Bug Fixes Complete

**Completed:** 2026-02-12
**Duration:** ~0.2 hours active development

## Summary

Fixed two UX bugs in macOS menubar Pomodoro timer:
1. App now automatically detects new calendar days while running overnight
2. Popover positioning stabilized on screens with auto-hiding menu bars

## Phases Completed

### Phase 1: Day Detection
- Implemented triple-redundancy day change detection system
- NSCalendarDayChanged notification + NSWorkspace.didWakeNotification + NSSystemTimeZoneDidChange + midnight timer fallback
- Timezone-safe DateFormatter with explicit TimeZone.current
- DST-safe midnight scheduling via Calendar.startOfDay
- **Files modified:** SlotManager.swift, DailySlots.swift, SlotManagerTests.swift

### Phase 2: Popover Positioning
- Fixed-width status item prevents button bounds changes
- Timer suspension during popover display
- Display change monitoring with graceful dismissal
- Menu bar visibility polling handles auto-hide scenario
- **Files modified:** PomodoroApp.swift
- **Known limitation:** Works on 2 of 3 screens (user accepted)

## Requirements Delivered

| Requirement | Description | Status |
|-------------|-------------|--------|
| DAY-01 | App detects new calendar day while running | ✓ Complete |
| DAY-02 | App detects day change after Mac wakes from sleep | ✓ Complete |
| DAY-03 | Day detection triggers full reinitialization | ✓ Complete |
| DAY-04 | Handle timezone changes correctly | ✓ Complete |
| DAY-05 | Handle DST transitions correctly | ✓ Complete |
| POP-01 | Popover remains anchored when menu bar auto-hides | ✓ Complete |
| POP-02 | Popover positions correctly on multi-monitor setups | ✓ Complete (2/3 screens) |
| POP-03 | Popover doesn't jump/jitter during timer updates | ✓ Complete |
| POP-04 | Graceful fallback if positioning fails | ✓ Complete |

## Key Commits

| Commit | Description |
|--------|-------------|
| eea20f5 | Add explicit timezone to DailySlots DateFormatter |
| 4d6ae37 | Add triple-redundancy day change detection |
| fb861ec | Add timezone test for DailySlots |
| a082aed | Add fixed-width status item with timer suspension |
| 2a6537f | Add screen coordinate caching and graceful dismissal |

## Metrics

- **Total commits:** 19 (including docs/planning)
- **Files changed:** 33
- **Code changes:** ~116 lines added to app code
- **Test changes:** 17 lines added
- **Plans executed:** 2
- **Tasks completed:** 6

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Triple-redundancy day detection | Multiple mechanisms ensure reliability across overnight, sleep/wake, and timezone scenarios |
| Explicit TimeZone.current | Prevents stale timezone cache issues during transitions |
| Calendar.startOfDay for midnight | DST-safe midnight calculation |
| Fixed width always on | Set once at initialization, prevents all button bounds changes |
| Graceful dismissal over repositioning | Cleaner UX when positioning becomes invalid |

## Known Limitations

- Third screen popover positioning: One of 3 screens still exhibits jump-to-corner behavior
- User accepted as sufficient given fix works on primary screens
- May need screen-specific positioning logic for complex multi-monitor setups in future

---
*Archived: 2026-02-12*
