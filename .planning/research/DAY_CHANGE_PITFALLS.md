# Domain Pitfalls: Day Change Detection on macOS

**Domain:** Calendar day boundary detection in long-running menubar applications
**Researched:** 2026-02-12

## Critical Pitfalls

### Pitfall 1: Single Detection Method (No Redundancy)
**What goes wrong:** Relying only on `.NSCalendarDayChanged` notification or only on timer-based detection. App fails to detect day change when Mac sleeps at midnight, or notification system has issues.

**Why it happens:**
- Developers assume one notification will cover all cases
- Timer-only approaches assume app stays running without suspension
- Notification-only approaches assume Mac stays awake at midnight

**Consequences:**
- User wakes up Mac at 9am, app still shows yesterday's data
- Statistics don't roll over, confusing UX
- Requires manual app restart or interaction to fix

**Prevention:**
- Implement hybrid approach: notification + wake detection + timer fallback
- Test overnight with Mac sleeping before midnight
- Verify each method independently and in combination

**Detection:**
- Overnight testing: Leave app running, sleep Mac at 11pm, wake at 8am
- Check if app shows correct date without user interaction
- Monitor logs to see which detection method fired

### Pitfall 2: Ignoring Sleep/Wake Cycle
**What goes wrong:** Not observing `NSWorkspace.didWakeNotification`. When Mac wakes from sleep, day may have changed but notification wasn't processed during sleep.

**Why it happens:**
- Focus on real-time detection, forgetting about suspended state
- Assumption that timer will fire even during sleep (it won't)
- Not considering typical usage pattern (Mac sleeps overnight)

**Consequences:**
- Most common failure mode - users typically don't leave Macs running overnight
- App shows stale data every morning
- "Works on my machine" in development (developer stays awake testing at midnight)

**Prevention:**
- Always add `NSWorkspace.didWakeNotification` observer
- Call `checkForNewDay()` on every wake event
- Test by sleeping Mac and checking date on wake

**Detection:**
- Put Mac to sleep for 5+ minutes
- Wake Mac and immediately check app state
- Should show current day without requiring app launch

### Pitfall 3: Timer Scheduling Without Rescheduling
**What goes wrong:**
```swift
// BAD: One-time timer that never reschedules
Timer.scheduledTimer(withTimeInterval: secondsUntilMidnight, repeats: false) { _ in
    checkForNewDay()
    // MISSING: scheduleNextMidnightTimer()
}
```
**Why it happens:**
- Forget that one-time timers need manual rescheduling
- Copy-paste timer code without understanding firing behavior
- Focus on "tonight's midnight" without planning for subsequent nights

**Consequences:**
- Works for first 24 hours, then never fires again
- Bug only appears after multiple days of continuous running
- Difficult to catch in testing

**Prevention:**
- Always reschedule timer in completion handler
- Use repeating timer with dynamic interval, or one-time with explicit reschedule
- Test app running continuously for 48+ hours (or simulate by manually advancing timer)

**Detection:**
- Let app run for 2-3 days continuously
- Verify day change detection on second and third night
- Log timer scheduling events to confirm rescheduling happens

### Pitfall 4: Direct Date Comparison Instead of Calendar Comparison
**What goes wrong:**
```swift
// BAD: Breaks with timezone changes and DST
if currentDate > lastCheckedDate {
    // Assumes new day
}

// GOOD: Calendar-aware comparison
if !Calendar.current.isDate(currentDate, inSameDayAs: lastCheckedDate) {
    // Day actually changed
}
```

**Why it happens:**
- Treating dates as simple timestamps rather than calendar concepts
- Not understanding timezone and DST complexity
- Copy-paste date logic from non-calendar contexts

**Consequences:**
- False positives when timezone changes during travel
- Miss day changes during DST "fall back" (2am happens twice)
- Incorrect behavior for users in different timezones than development

**Prevention:**
- Always use `Calendar.current` for day comparisons
- Use `.isDate(_:inSameDayAs:)` or `.compare(_:to:toGranularity: .day)`
- Test with manual timezone changes in System Preferences

**Detection:**
- Change system timezone from PST to EST (3 hour jump)
- Verify app doesn't trigger false day change
- Test during actual DST transition dates

## Moderate Pitfalls

### Pitfall 5: Not Testing with Menubar Auto-Hide
**What goes wrong:** App works fine with menubar always visible, but fails when user has auto-hiding menubar enabled. Detection methods may not fire reliably when menubar is hidden.

**Why it happens:**
- Development machines rarely use auto-hide menubar
- Assumption that background app behavior is consistent regardless of UI state

**Prevention:**
- Test with `System Preferences → Dock & Menu Bar → Automatically hide the menu bar`
- Verify notifications and timers fire when menubar hidden
- Check logs when app is idle with menubar hidden

**Detection:**
- Enable auto-hide menubar in System Preferences
- Leave app idle overnight with menubar hidden
- Verify day change detection still works

### Pitfall 6: Race Condition Around Midnight
**What goes wrong:** Multiple detection methods fire simultaneously at midnight, causing duplicate processing or state corruption.

**Why it happens:**
- Notification and timer both fire at same moment
- No guard against re-entrant calls
- State updates not idempotent

**Prevention:**
- Use existing `checkForNewDay()` guard (line 389: `if today.dateString != todayString`)
- Ensure state updates are idempotent
- Consider debouncing if multiple calls cause UI flicker

**Detection:**
- Deliberately call `checkForNewDay()` multiple times in quick succession
- Check for duplicate history entries or incorrect state
- Look for UI flickering or animation issues

### Pitfall 7: Hardcoded Timezone Assumptions
**What goes wrong:**
```swift
// BAD: Assumes specific timezone
let midnight = Calendar(identifier: .gregorian).date(
    bySettingHour: 0, minute: 0, second: 0,
    of: Date()
)
```

**Why it happens:**
- Testing only in single timezone
- Not realizing `Calendar.current` respects system timezone
- Copy-paste from examples that use hardcoded calendars

**Prevention:**
- Always use `Calendar.current` (auto-uses system timezone)
- Never hardcode timezone in calendar operations
- Test by changing system timezone

**Detection:**
- Change System Preferences timezone
- Verify midnight detection uses new timezone
- Check that day boundary matches system clock, not UTC

## Minor Pitfalls

### Pitfall 8: Over-Engineering Custom Calendar Logic
**What goes wrong:** Implementing custom day-of-year calculations, manual DST handling, or timezone conversion instead of using Foundation APIs.

**Why it happens:**
- Mistrust of Foundation Calendar APIs
- "Not invented here" syndrome
- Trying to optimize prematurely

**Prevention:**
- Trust `Calendar.current` - it's battle-tested and handles edge cases
- Use `.startOfDay(for:)` instead of manual hour/minute/second setting
- Only optimize if profiling shows actual performance issue

**Detection:**
- Code review: look for manual date math instead of Calendar methods
- Check for bugs around DST transitions (custom logic usually fails here)

### Pitfall 9: Not Cleaning Up Observers
**What goes wrong:** Adding observers without removing them in deinit, causing memory leaks or crashes when object deallocated.

**Why it happens:**
- Forget that NotificationCenter holds strong reference
- Not understanding observer lifecycle
- Copy-paste observer code without cleanup code

**Prevention:**
```swift
deinit {
    NotificationCenter.default.removeObserver(self)
}
```

**Detection:**
- Check for memory leaks with Instruments
- Look for crashes related to deallocated observer being called
- Code review for observer registration without removal

### Pitfall 10: Excessive Logging/Debugging in Production
**What goes wrong:** Logging every timer fire or notification receipt fills up console/disk in production.

**Why it happens:**
- Debugging logic left in shipping code
- No log level differentiation
- Timer fires frequently (if using polling approach)

**Prevention:**
- Use conditional compilation: `#if DEBUG` for verbose logs
- Log only actual day changes, not every check
- Use log levels appropriately (debug vs info vs error)

**Detection:**
- Check Console.app log volume after running app for days
- Measure disk space used by logs over time

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Initial notification implementation | Pitfall 1 (single method) | Implement all three methods from start |
| Timer scheduling | Pitfall 3 (no reschedule) | Add reschedule logic in first implementation |
| Testing | Pitfall 2 (no sleep testing) | Create test plan including overnight sleep scenarios |
| Edge case handling | Pitfall 4 (direct date comparison) | Use Calendar API from first line of code |
| Production deployment | Pitfall 6 (race conditions) | Verify idempotent state updates before shipping |

## Testing Checklist to Avoid Pitfalls

- [ ] App runs overnight with Mac awake - day changes at midnight
- [ ] App runs overnight with Mac asleep - day changes on wake
- [ ] Timezone changed during app runtime - day change happens at new timezone midnight
- [ ] DST transition dates - day change happens correctly during "spring forward" and "fall back"
- [ ] Multiple rapid calls to `checkForNewDay()` - no duplicate processing or crashes
- [ ] App runs continuously for 7+ days - day changes every night
- [ ] Menubar auto-hide enabled - detection methods still fire
- [ ] App quit and relaunched - day detection works immediately

## Sources

- Codebase analysis: `/Users/pedf/workspace/pomodoro-mac/PomodoroApp/Models/SlotManager.swift`
- Foundation Calendar API patterns (training data knowledge)
- Common macOS app architecture anti-patterns (training data knowledge)
- NSWorkspace notification patterns (training data knowledge)

**Note:** Research conducted without access to official Apple documentation. Pitfalls based on established Foundation API patterns and common developer mistakes from training data (cutoff January 2025).
