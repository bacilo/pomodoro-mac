# Requirements: PomodoroApp Bug Fixes

**Defined:** 2026-02-12
**Core Value:** The timer must reliably track work sessions and automatically reset for each new day without manual intervention.

## v1 Requirements

Requirements for this bug fix release. Each maps to roadmap phases.

### Day Detection

- [ ] **DAY-01**: App detects new calendar day while running (passive monitoring via notifications)
- [ ] **DAY-02**: App detects day change after Mac wakes from sleep
- [ ] **DAY-03**: Day detection triggers full reinitialization (archive yesterday, fresh state, template prompt if applicable)
- [ ] **DAY-04**: Handle timezone changes correctly
- [ ] **DAY-05**: Handle DST transitions correctly

### Popover Positioning

- [ ] **POP-01**: Popover remains anchored when menu bar auto-hides
- [ ] **POP-02**: Popover positions correctly on multi-monitor setups
- [ ] **POP-03**: Popover doesn't jump or jitter during timer/marquee updates
- [ ] **POP-04**: Graceful fallback if positioning fails (dismiss cleanly rather than jump to corner)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Polish

- **POL-01**: Smooth animated transitions during popover reanchoring
- **POL-02**: Remember preferred screen for popover display

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Custom window-based popover | High complexity, NSPopover sufficient if fixed correctly |
| Major architecture refactor | Minimal changes to fix bugs, not rebuild |
| Cloud sync | Single-device app by design |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| DAY-01 | Phase 1 | Pending |
| DAY-02 | Phase 1 | Pending |
| DAY-03 | Phase 1 | Pending |
| DAY-04 | Phase 1 | Pending |
| DAY-05 | Phase 1 | Pending |
| POP-01 | Phase 2 | Pending |
| POP-02 | Phase 2 | Pending |
| POP-03 | Phase 2 | Pending |
| POP-04 | Phase 2 | Pending |

**Coverage:**
- v1 requirements: 9 total
- Mapped to phases: 9
- Unmapped: 0

---
*Requirements defined: 2026-02-12*
*Last updated: 2026-02-12 after roadmap creation*
