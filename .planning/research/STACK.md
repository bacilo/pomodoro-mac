# Technology Stack: Day Change Detection

**Project:** PomodoroApp Bug Fix - Passive Day Detection
**Researched:** 2026-02-12
**Target:** macOS 13.0+

## Current State Analysis

**Existing implementation:** `SlotManager.checkForNewDay()` (line 387-394)
- Triggers: App launch (init), `NSApplication.didBecomeActiveNotification`
- Gap: No passive detection while app runs in menubar
- Result: Day won't roll over at midnight unless user interacts with app

## Recommended Stack

### Primary Approach: Notification-Based Detection

| Technology | Purpose | Why | Confidence |
|------------|---------|-----|------------|
| `Notification.Name.NSCalendarDayChanged` | Midnight boundary detection | System posts at calendar day rollover, handles timezone changes automatically | MEDIUM |
| `NotificationCenter.default` | Observer registration | Standard Foundation pattern already used in app (line 58-63 of PomodoroApp.swift) | HIGH |
| `NSWorkspace.didWakeNotification` | Sleep recovery | Detect day changes that occurred while Mac was asleep | HIGH |

**Implementation pattern:**
```swift
// In SlotManager.init() or AppDelegate.applicationDidFinishLaunching
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleDayChanged),
    name: .NSCalendarDayChanged,
    object: nil
)

NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleSystemWake),
    name: NSWorkspace.didWakeNotification,
    object: nil
)
```

**Rationale:**
- `.NSCalendarDayChanged` is designed specifically for this use case
- System handles timezone changes, DST transitions automatically
- No polling overhead - event-driven only
- Works in background (menubar apps remain active)

### Fallback Approach: Timer-Based Detection

| Technology | Purpose | Why | Confidence |
|------------|---------|-----|------------|
| `Timer.scheduledTimer(withTimeInterval:repeats:)` | Manual midnight scheduling | Fallback if notifications unreliable | HIGH |
| `Calendar.current.startOfDay(for:)` | Next midnight calculation | Precise calendar-aware date math | HIGH |
| `Calendar.current.dateComponents(_:from:to:)` | Day comparison | Reliable day boundary checking | HIGH |

**Implementation pattern:**
```swift
private func scheduleNextMidnightCheck() {
    let calendar = Calendar.current
    let now = Date()

    // Calculate next midnight
    guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
          let nextMidnight = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: tomorrow)) else {
        return
    }

    let timeUntilMidnight = nextMidnight.timeIntervalSince(now)

    Timer.scheduledTimer(withTimeInterval: timeUntilMidnight, repeats: false) { [weak self] _ in
        self?.checkForNewDay()
        self?.scheduleNextMidnightCheck() // Reschedule for next day
    }
}
```

**When to use:**
- If `.NSCalendarDayChanged` doesn't fire reliably in testing
- As supplementary check (belt-and-suspenders approach)
- Consider scheduling timer 5 seconds after midnight to avoid edge cases

### Supporting APIs

| API | Purpose | When to Use | Confidence |
|-----|---------|-------------|------------|
| `Calendar.current.isDateInToday(_:)` | Validate if date is today | Quick check before initializing new day | HIGH |
| `Calendar.current.compare(_:to:toGranularity:)` | Compare dates at day level | Ignore time components when checking if day changed | HIGH |
| `DateFormatter` with "yyyy-MM-dd" | String-based day tracking | Already used in `DailyStats` (line 10-14 of Statistics.swift) | HIGH |

## Anti-Patterns to Avoid

### Anti-Pattern 1: Polling with Short Intervals
**What:** `Timer` firing every minute/second to check date
**Why bad:**
- Wastes CPU cycles (1440+ checks per day vs 1 event)
- Prevents app nap / energy efficiency
- Race conditions around midnight
**Instead:** Use notification-based or single timer scheduled for midnight

### Anti-Pattern 2: Comparing Date() Directly
**What:**
```swift
if Date() > lastCheckDate {
    // Assume new day
}
```
**Why bad:**
- Doesn't account for timezone changes
- Breaks with DST transitions
- Not calendar-aware (some cultures have different day boundaries)
**Instead:** Use `Calendar.current.compare(_:to:toGranularity: .day)`

### Anti-Pattern 3: Ignoring Sleep/Wake Cycle
**What:** Only checking on user interaction
**Why bad:**
- Mac sleeps overnight, app doesn't process midnight notification
- User opens app next morning, still showing yesterday's data
**Instead:** Always check on `NSWorkspace.didWakeNotification`

### Anti-Pattern 4: Hardcoded Timezone Assumptions
**What:**
```swift
// BAD: Assumes UTC or specific timezone
let midnight = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: date)
```
**Why bad:**
- User timezone != app timezone assumption
- Breaks when traveling or changing system timezone
**Instead:** `Calendar.current` respects system timezone automatically

## Implementation Recommendation

**Recommended hybrid approach:**

1. **Primary:** Register `.NSCalendarDayChanged` notification observer
2. **Backup:** Register `NSWorkspace.didWakeNotification` observer (always check on wake)
3. **Fallback:** Schedule midnight timer as safety net
4. **Validation:** All handlers call same `checkForNewDay()` method with guard against duplicate processing

**Code location:** Modify `SlotManager.init()` to add observers, similar to pattern in `AppDelegate.applicationDidFinishLaunching` (line 46-108 of PomodoroApp.swift)

**Why hybrid:**
- `.NSCalendarDayChanged` may not fire if Mac asleep at midnight
- Wake notification catches sleep-induced gaps
- Timer provides absolute guarantee even if notifications fail
- Single `checkForNewDay()` prevents duplicate processing (line 387-394 already has date comparison guard)

## Testing Considerations

| Test Scenario | How to Simulate |
|---------------|-----------------|
| Normal midnight rollover | `date -s "23:59:50"` (requires sudo, or wait for real midnight) |
| Timezone change | System Preferences → Date & Time → Change timezone |
| Sleep/wake across midnight | Put Mac to sleep before midnight, wake after |
| DST transition | Wait for actual DST date, or manipulate system clock |

**macOS 13+ compatibility:** All APIs mentioned available since macOS 10.9+, safe for target deployment.

## Confidence Assessment

| Recommendation | Confidence | Rationale |
|----------------|------------|-----------|
| `.NSCalendarDayChanged` notification | MEDIUM | Training data indicates this exists, but official docs unavailable to verify exact name and reliability in menubar apps. Needs testing. |
| `NSWorkspace.didWakeNotification` | HIGH | Well-documented, widely used pattern for sleep/wake handling |
| Timer-based midnight scheduling | HIGH | Calendar math APIs well-documented and reliable |
| Hybrid approach (all three) | HIGH | Defense in depth - one method will work even if others fail |

## Open Questions / Validation Needed

1. **CRITICAL:** Verify exact notification name - training data suggests `.NSCalendarDayChanged` but couldn't access official docs. Test in real app to confirm it fires.
2. Does `.NSCalendarDayChanged` fire for menubar-only apps (LSUIElement = true)?
3. Does notification fire if Mac asleep at midnight? (Likely NO - hence need for wake notification)
4. Performance impact of three-method approach - probably negligible but worth measuring

## Sources

- Current codebase analysis: `/Users/pedf/workspace/pomodoro-mac/PomodoroApp/Models/SlotManager.swift`
- Current codebase analysis: `/Users/pedf/workspace/pomodoro-mac/PomodoroApp/PomodoroApp.swift`
- API knowledge: Foundation framework (Calendar, NotificationCenter, Timer patterns)
- **Note:** Official Apple documentation unavailable during research session. Recommendations based on training data knowledge of Foundation APIs (January 2025 cutoff). All notification names and API details flagged for verification.

## Next Steps

1. **Test notification name:** Create minimal test to verify `.NSCalendarDayChanged` fires at midnight
2. **Prototype hybrid approach:** Implement all three detection methods in SlotManager
3. **Validate edge cases:** Test timezone changes, DST transitions, sleep/wake cycles
4. **Measure reliability:** Run overnight tests to confirm day rollover detection works
