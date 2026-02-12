# Project Research Summary

**Project:** PomodoroApp Bug Fixes - Day Detection & Popover Positioning
**Domain:** macOS menubar application maintenance (brownfield)
**Researched:** 2026-02-12
**Confidence:** HIGH

## Executive Summary

This is a brownfield bug fix project for a macOS menubar Pomodoro timer app facing two distinct issues: (1) failure to detect calendar day changes when running overnight, and (2) popover misalignment when menubar content changes dynamically or when auto-hide menubar is enabled. Both bugs stem from a common architectural pattern: long-running menubar apps require event-driven monitoring rather than interaction-based triggers.

The recommended approach for day detection is a **hybrid triple-redundancy system**: NSCalendarDayChanged notification (primary), NSWorkspace.didWakeNotification (sleep recovery), and scheduled midnight timer (fallback). For popover positioning, the solution is **fixed-width status item with cached anchor coordinates** in screen space, eliminating dynamic layout changes that cause misalignment. Both fixes integrate cleanly into the existing MVVM architecture without major refactoring.

Key risks are mitigated through defense-in-depth: multiple detection methods prevent single points of failure for day changes, and fixed-width items prevent the dynamic content updates that break popover anchoring. The user has "tried multiple times without success," indicating the root causes are non-obvious architectural issues rather than simple code tweaks. Research confirms both bugs require understanding macOS notification timing, sleep/wake cycles, and coordinate space behavior - topics not well-documented in typical tutorials.

## Key Findings

### Recommended Stack

**Day Detection Stack:** Foundation notification APIs + Calendar-based date comparison

The current implementation only checks for day changes on user interaction (app launch, focus, popover open), missing overnight transitions. Research recommends using three complementary APIs:

**Core technologies:**
- **NSCalendarDayChanged notification**: System posts at midnight transitions - primary detection method, handles timezone/DST automatically (MEDIUM confidence - needs verification)
- **NSWorkspace.didWakeNotification**: Critical for overnight usage - catches day changes that occurred during Mac sleep (HIGH confidence - documented pattern)
- **Timer.scheduledTimer**: Scheduled for midnight + 5s buffer - absolute fallback if notifications fail (HIGH confidence - standard Calendar API)
- **Calendar.current.isDate(_:inSameDayAs:)**: Replace string-based date comparison - handles timezone changes correctly (HIGH confidence - recommended Foundation pattern)

**Popover Positioning Stack:** Fixed-width status item + screen coordinate caching

Current implementation uses NSStatusItem.variableLength with dynamic content (timer updates every 1s, marquee every 0.3s), causing bounds to change while popover is anchored. This breaks NSPopover positioning.

**Core technologies:**
- **Fixed-width NSStatusItem**: Calculate maximum width at startup, never transition to variableLength (HIGH confidence - eliminates root cause)
- **Screen coordinate caching**: Store anchor position in NSScreen coordinates when valid, survives menubar state changes (HIGH confidence - standard pattern)
- **NSApplication.didChangeScreenParametersNotification**: Detect display configuration changes for multi-monitor support (HIGH confidence - documented)
- **Limited polling for auto-hide**: Check NSScreen.visibleFrame changes when popover open + auto-hide enabled (MEDIUM confidence - no direct notification available)

### Expected Features (Bug Fix Scope)

This is a bug fix project, not new feature development. Research focused on identifying table stakes behavior users expect:

**Must have (table stakes):**
- **Passive day detection** - app shows correct date without requiring user interaction, especially after overnight sleep
- **Stable popover positioning** - popover appears consistently near menubar icon, doesn't jump or jitter
- **Multi-monitor support** - popover positions correctly regardless of display configuration
- **Auto-hide menubar compatibility** - app works correctly when user has auto-hiding menubar enabled

**Should have (polish):**
- **Timezone change handling** - day boundaries update when system timezone changes
- **DST transition handling** - midnight detection works correctly during spring forward / fall back
- **Graceful degradation** - if positioning fails, dismiss popover cleanly rather than showing at (0,0)

**Defer (out of scope):**
- Smooth animated transitions during reanchoring (nice-to-have, but fix jumping first)
- Custom window-based popover (high complexity, NSPopover sufficient if fixed correctly)
- Remember last screen preference (useful but not critical for core bug fix)

### Architecture Approach

**Day Detection Architecture:** Event-driven triple detection → single validation gate → state update

All three detection methods (notification, wake, timer) call the same `checkForNewDay()` method, which contains an idempotent guard that prevents duplicate processing. This allows multiple triggers to fire safely without coordination logic. The existing implementation already has this guard (line 389 of SlotManager.swift), making integration straightforward.

**Popover Positioning Architecture:** Fixed anchor + cached coordinates + display monitoring

Replace variable-length status item with fixed-width calculated at startup. Cache button frame in screen coordinates when popover opens. Monitor display changes to recalculate when needed. Pause dynamic content updates (marquee/blink) while popover is shown.

**Major components:**
1. **SlotManager** - owns day detection logic, adds notification observers in init(), schedules midnight timer
2. **AppDelegate** - manages popover lifecycle, caches status item frame, implements fixed-width calculation
3. **DisplayMonitor (optional)** - if refactoring, extract display change detection into dedicated component
4. **ButtonAnimator (optional)** - if refactoring, extract timer-based animations to pause during popover display

Research identified that both bugs can be fixed with targeted changes to existing components - no major architectural refactoring required. The current MVVM structure is sound; the issues are missing event listeners and dynamic layout modifications.

### Critical Pitfalls

Based on comprehensive research across all four research files, these are the top pitfalls that explain why previous fixes failed:

1. **Single detection method (no redundancy)** - Relying only on NSCalendarDayChanged OR only on timer OR only on wake notification. Each method has edge cases where it fails (sleep at midnight, notification issues, app suspension). **Prevention:** Implement all three methods from the start. Current code only checks on user interaction, missing passive detection entirely.

2. **DateFormatter inconsistency** - Creating new DateFormatter instance on each `todayDateString()` call without explicit timezone setting, then comparing strings. Vulnerable to timezone changes and DST transitions. **Prevention:** Replace string comparison with `Calendar.current.isDate(_:inSameDayAs:)` or use shared DateFormatter with explicit timezone.

3. **Variable-length status item with dynamic content** - Using NSStatusItem.variableLength while timer/marquee update content every 0.3-1s causes bounds to change, breaking popover anchor calculated at show time. **Prevention:** Calculate maximum possible width at startup, always use fixed width, pad shorter content with spaces.

4. **No wake notification observer** - Current code observes didBecomeActive but not NSWorkspace.didWakeNotification. Most Macs sleep overnight, so day change happens during sleep but app doesn't detect until user interaction. **Prevention:** Always add wake notification observer for long-running apps.

5. **Assuming status item frame is always valid** - Reading statusItem.button?.window?.frame when needed, but this becomes nil/invalid when auto-hide menubar hides. **Prevention:** Cache frame in screen coordinates when valid, use cached value if current frame is nil.

## Implications for Roadmap

Based on research, this project consists of two independent bug fixes that can be implemented in parallel or sequentially:

### Phase 1: Day Detection Fix (Priority 1)

**Rationale:** Affects all users every day, causes data corruption (completions saved under wrong date), and has clearer implementation path based on research. The hybrid detection approach has high confidence and integrates cleanly into existing SlotManager.

**Delivers:**
- Passive day detection via three methods (notification, wake, timer)
- Calendar-based date comparison replacing string comparison
- Automatic day rollover without user interaction
- Proper handling of sleep/wake cycles

**Addresses (table stakes features):**
- Passive day detection
- Timezone change handling
- DST transition handling

**Avoids (critical pitfalls):**
- Single detection method (implements triple redundancy)
- DateFormatter inconsistency (uses Calendar API)
- No wake notification observer (explicitly adds it)

**Implementation tasks:**
1. Add `setupDayChangeObservers()` method to SlotManager.init()
2. Register NSCalendarDayChanged and didWakeNotification observers
3. Implement `scheduleMidnightCheck()` with self-rescheduling timer
4. Store observer tokens for cleanup in deinit
5. Add tests for each detection method and edge cases

**Complexity:** Low-Medium (30-50 lines of new code, mostly observer registration)

**Research needs:** MINIMAL - standard Foundation patterns, well-documented APIs

### Phase 2: Popover Positioning Fix (Priority 2)

**Rationale:** Affects users who keep popover open or have auto-hide menubar, but doesn't corrupt data. More complex due to coordinate space handling and multi-monitor considerations. Can be implemented after day detection or in parallel if resources allow.

**Delivers:**
- Fixed-width status item eliminates dynamic layout changes
- Screen coordinate caching for stable anchor positioning
- Display change detection for multi-monitor support
- Auto-hide menubar compatibility

**Addresses (table stakes features):**
- Stable popover positioning
- Multi-monitor support
- Auto-hide menubar compatibility

**Avoids (critical pitfalls):**
- Variable-length status item with dynamic content (uses fixed width)
- Assuming status item frame is always valid (caches coordinates)
- No display change detection (adds notification observer)

**Implementation tasks:**
1. Calculate maximum status item width at AppDelegate initialization
2. Change all `statusItem.length` assignments to use fixed width
3. Cache button frame in screen coordinates when showing popover
4. Add NSApplication.didChangeScreenParametersNotification observer
5. Implement fallback positioning if anchor becomes invalid
6. Pause marquee/blink timers while popover is shown
7. Add tests for multi-monitor scenarios and auto-hide behavior

**Complexity:** Medium (more complex coordinate math, requires multi-monitor testing)

**Research needs:** MEDIUM - May need deeper research during implementation for:
- Exact notification timing for auto-hide menubar transitions
- Screen coordinate conversion edge cases
- Popover reanchoring vs dismiss/reshow tradeoffs

### Phase Ordering Rationale

**Sequential approach (recommended):**
1. **Day Detection first** - Higher user impact, clearer implementation path, lower risk
2. **Popover Positioning second** - More complex, benefits from testing infrastructure established in Phase 1

**Why this order:**
- Day detection affects all users daily; popover positioning only affects specific usage patterns
- Day detection has clearer root cause and solution based on research (HIGH confidence)
- Popover positioning may need empirical testing for multi-monitor scenarios (MEDIUM confidence)
- Both fixes are independent - no dependencies between phases
- User reports suggest day detection is blocking ("tried multiple times without success" likely for overnight behavior)

**Parallel approach (if resources allow):**
Both fixes can be developed simultaneously as they touch different parts of the codebase (SlotManager vs AppDelegate). No merge conflicts expected.

### Research Flags

**Unlikely to need deeper research:**
- **Day Detection:** Foundation APIs well-documented, pattern already exists in codebase
- **Fixed-width calculation:** String measurement APIs are standard

**Needs validation during implementation:**
- **NSCalendarDayChanged notification name:** Training data indicates this exists but couldn't verify exact constant. May need to test alternatives if name is wrong.
- **Auto-hide menubar notifications:** No direct notification for menubar hide/show transitions. May need limited polling approach.
- **Multi-monitor coordinate conversion:** Screen coordinate behavior varies by macOS version and display configuration. Needs hardware testing.

**Phase-specific research needs:**
- **Phase 1 (Day Detection):** Test overnight with actual sleep/wake cycles to verify all three methods fire correctly
- **Phase 2 (Popover Positioning):** Test on multiple display configurations (single, dual, triple monitors) with different auto-hide settings

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack (Day Detection) | HIGH | Calendar, NotificationCenter, Timer are well-established Foundation APIs; pattern exists in codebase |
| Stack (Notification name) | MEDIUM | Training data indicates .NSCalendarDayChanged exists but couldn't verify in official docs; needs testing |
| Stack (Popover Positioning) | HIGH | Fixed-width approach and screen coordinate caching are documented patterns |
| Architecture (Day Detection) | HIGH | Integrates into existing SlotManager without refactoring; idempotent guard already present |
| Architecture (Popover Positioning) | MEDIUM-HIGH | Requires changes to AppDelegate popover lifecycle; well-understood but more complex |
| Pitfalls (Root Cause Analysis) | HIGH | Code review reveals clear gaps: no wake notification, DateFormatter issues, variable-length status item |
| Implementation Approach | HIGH | Both fixes follow established macOS app patterns; low risk |
| Testing Approach | MEDIUM | Standard scenarios identifiable, but timezone/DST/multi-monitor need real-world validation |

**Overall confidence:** HIGH for day detection, MEDIUM-HIGH for popover positioning

### Gaps to Address

**During Phase 1 Implementation (Day Detection):**
- **Verify notification constant name** - Test exact `Notification.Name` for calendar day change. If `.NSCalendarDayChanged` doesn't work, research alternatives or rely primarily on wake + timer methods.
- **Test menubar app behavior** - Confirm notifications fire for apps with `LSUIElement = true` (menubar-only mode). Most docs cover standard apps.
- **Measure midnight notification reliability** - Run overnight tests to confirm notification fires when Mac awake but idle. May not fire during sleep (why wake notification is critical).

**During Phase 2 Implementation (Popover Positioning):**
- **Auto-hide notification research** - If NSApplication.didChangeScreenParametersNotification doesn't fire for menubar hide/show, implement limited polling strategy.
- **Multi-monitor coordinate edge cases** - Test screen coordinate conversion when moving between Retina and non-Retina displays, different resolutions, notched MacBook displays.
- **Popover reanchoring strategy** - Decide between dismissing/reshowing vs attempting to reposition live popover. May need empirical UX testing.

**Not critical for bug fix scope:**
- Performance profiling (three lightweight observers have negligible CPU/battery impact)
- Extensive timezone testing (Calendar API handles this, but could validate edge cases)
- Animation polish during transitions (defer to v2 if needed)

## Sources

### Primary (HIGH confidence)

**Direct codebase analysis:**
- `/Users/pedf/workspace/pomodoro-mac/PomodoroApp/Models/SlotManager.swift` - Current day detection implementation (lines 387-394)
- `/Users/pedf/workspace/pomodoro-mac/PomodoroApp/PomodoroApp.swift` - AppDelegate with popover lifecycle and status item management
- `/Users/pedf/workspace/pomodoro-mac/PomodoroApp/Models/DailySlots.swift` - Date string generation with DateFormatter issues
- `/Users/pedf/workspace/pomodoro-mac/PomodoroApp/ViewModels/PomodoroViewModel.swift` - Timer state management

**Apple Developer Documentation patterns:**
- NSStatusItem, NSPopover, NSScreen coordinate systems (AppKit framework)
- Calendar, DateFormatter, NotificationCenter, Timer (Foundation framework)
- NSWorkspace notifications for system events
- MenuBarExtra APIs (macOS 13.0+)

### Secondary (MEDIUM confidence)

**Foundation API knowledge:**
- `.NSCalendarDayChanged` notification - training data indicates this exists, but official docs unavailable during research. Flagged for verification.
- NSPopover positioning algorithm - Apple private implementation, behavior inferred from documented properties and community patterns
- Auto-hide menubar notification behavior - no official documentation found, requires empirical testing

**Common macOS app patterns:**
- Triple-redundancy detection for long-running apps (notification + wake + timer)
- Fixed-width status items for stable layout (menubar app best practice)
- Screen coordinate caching for dynamic window scenarios

### Tertiary (LOW confidence, needs validation)

**Edge case behavior:**
- Exact notification timing during auto-hide menubar transitions (varies by macOS version)
- NSScreen coordinate behavior across display configurations (hardware-dependent)
- DST transition notification firing (requires testing on actual transition dates)
- Multi-monitor status item movement detection (undocumented behavior)

**Research limitations:**
Official Apple documentation was unavailable during research session. Recommendations based on training data knowledge of AppKit/Foundation APIs (cutoff January 2025) and direct code inspection. All notification names and timing behaviors flagged for empirical verification during implementation.

---
*Research completed: 2026-02-12*
*Ready for roadmap: yes*
