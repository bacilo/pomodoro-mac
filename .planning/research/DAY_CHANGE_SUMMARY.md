# Research Summary: Day Change Detection for macOS Menubar App

**Domain:** System event detection for macOS menubar applications
**Researched:** 2026-02-12
**Overall confidence:** MEDIUM-HIGH

## Executive Summary

The PomodoroApp currently only detects calendar day changes when the user interacts with the app (launch or activation). This creates a poor UX where overnight the app continues showing yesterday's data until user interaction. The research identifies three complementary approaches to passive day detection:

1. **Notification-based detection** via `.NSCalendarDayChanged` (posted by system at midnight)
2. **Sleep/wake detection** via `NSWorkspace.didWakeNotification` (catches changes during sleep)
3. **Timer-based detection** via scheduled midnight timers (fallback guarantee)

The recommended solution is a **hybrid approach using all three methods**. Each method guards against edge cases where others might fail (sleep at midnight, notification system issues, timezone changes). The existing `checkForNewDay()` method already has date comparison logic that prevents duplicate processing, making it safe to call from multiple triggers.

All APIs are available in macOS 13.0+ (actually available since 10.9+), well-tested in production apps, and align with the existing codebase architecture (already using NotificationCenter in AppDelegate). Implementation complexity is low - approximately 30-50 lines of code in `SlotManager.init()`.

The primary uncertainty is whether `.NSCalendarDayChanged` reliably fires in menubar-only apps (LSUIElement = true), which requires testing. If unreliable, the sleep/wake notification and timer fallback provide complete coverage.

## Key Findings

**Stack:** Hybrid approach using Foundation APIs - `.NSCalendarDayChanged` notification (primary), `NSWorkspace.didWakeNotification` (sleep recovery), `Timer` scheduled for midnight (fallback)

**Architecture:** Event-driven detection with three triggers → single validation method (`checkForNewDay()`) → updates SlotManager state

**Critical pitfall:** Single-method approaches fail in edge cases - notification doesn't fire during sleep, wake notification only fires after sleep, timer might not fire if app suspended

## Implications for Roadmap

Based on research, suggested implementation approach:

### Single Implementation Phase
This bug fix doesn't require multiple phases - it's a focused enhancement to existing `SlotManager`:

**Implementation tasks:**
1. Add notification observers in `SlotManager.init()` for `.NSCalendarDayChanged` and wake events
2. Add midnight timer scheduling (called once, auto-reschedules)
3. Update all handlers to call existing `checkForNewDay()` method
4. Add tests for observer registration and day comparison edge cases

**Rationale:** All three detection methods integrate into existing architecture without structural changes. The `checkForNewDay()` method (line 387-394 of SlotManager.swift) already handles validation and state updates correctly.

### Phase Ordering Rationale

Not applicable - this is a single-phase bug fix, not a multi-phase project. However, if broken into subtasks for development:

1. **First:** Notification-based detection (lowest risk, follows existing patterns)
2. **Second:** Wake notification (complements primary approach)
3. **Third:** Timer fallback (safety net, slightly more complex scheduling logic)

This ordering allows testing each method independently while building toward comprehensive coverage.

### Research Flags for Implementation

**Unlikely to need deeper research:**
- Foundation APIs (Calendar, NotificationCenter, Timer) are well-documented and stable
- Pattern already exists in codebase (AppDelegate lines 58-63)
- Implementation is straightforward observer registration

**Needs validation during implementation:**
- Exact notification constant name (`.NSCalendarDayChanged` vs other variants)
- Reliability of day-change notification in menubar apps (may require overnight testing)
- Whether notification fires during sleep (probably NO - hence multiple methods needed)

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack (APIs) | HIGH | Calendar, NotificationCenter, Timer are well-established Foundation APIs available since macOS 10.9+ |
| Stack (notification name) | MEDIUM | Training data indicates `.NSCalendarDayChanged` exists, but couldn't verify exact constant name in official docs during research |
| Architecture | HIGH | Pattern already used in existing codebase (AppDelegate notification observers) |
| Implementation approach | HIGH | Hybrid strategy covers all edge cases, aligns with existing patterns |
| Testing approach | MEDIUM | Standard scenarios identifiable, but timezone/DST edge cases need real-world validation |

## Gaps to Address

### During Implementation
1. **Verify notification constant:** Test exact `Notification.Name` for calendar day change event. If `.NSCalendarDayChanged` doesn't work, check alternatives or rely on wake + timer.
2. **Test menubar app behavior:** Confirm notifications fire for apps with `LSUIElement = true` (menubar-only mode)
3. **Measure midnight notification reliability:** Run overnight tests to see if notification fires when Mac is awake but user idle

### Not Critical for This Bug Fix
- Performance profiling (three lightweight observers have negligible impact)
- Extensive timezone testing (Calendar API handles this, but could validate with world clock testing)
- Localization considerations (day boundaries may differ in some cultures - but Calendar.current should handle this)

## Technical Debt Considerations

**None introduced:** This approach uses standard Foundation patterns already in the codebase. Adding observers follows existing precedent in `AppDelegate.applicationDidFinishLaunching`.

**Potential cleanup:** Could consolidate all day-change logic into a dedicated `DayChangeDetector` class if codebase grows, but current SlotManager integration is appropriate for this scale.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Notification doesn't fire | Medium | High | Use three methods (one will work) |
| Multiple triggers fire simultaneously | Low | Low | `checkForNewDay()` already has guard (line 389) |
| Timer drift over time | Low | Low | Recalculate next midnight after each fire |
| Timezone change during runtime | Low | Medium | Calendar API auto-handles, but wake notification catches gaps |
| Mac sleeps at midnight | High | High | Wake notification explicitly handles this |

**Overall risk:** LOW - Hybrid approach provides redundancy, existing code already handles duplicate calls safely.
