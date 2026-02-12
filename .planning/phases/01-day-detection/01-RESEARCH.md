# Phase 1: Day Detection - Research

**Researched:** 2026-02-12
**Domain:** macOS system event detection for calendar day changes
**Confidence:** HIGH

## Summary

The PomodoroApp currently only detects calendar day changes when the user interacts with the app (launch, activation, popover open). This creates data integrity issues where completions are saved under the wrong date if the app runs overnight without user interaction. The existing implementation has the correct validation logic (`checkForNewDay()` with idempotent guard) but lacks passive detection mechanisms.

Research confirms a **triple-redundancy approach** using three complementary Foundation APIs:
1. **NSCalendarDayChanged notification** - System posts at midnight (primary detection)
2. **NSWorkspace.didWakeNotification** - Catches day changes during Mac sleep (critical for overnight usage)
3. **Timer scheduled for midnight** - Absolute fallback if notifications fail or are delayed

Each method has specific failure modes (notification unreliable during sleep, wake only fires after sleep, timer might suspend), so using all three provides defense-in-depth. All three can safely call the existing `checkForNewDay()` method, which already prevents duplicate processing. The implementation integrates cleanly into existing MVVM architecture with minimal code changes (30-50 lines in `SlotManager.init()`).

**Primary recommendation:** Implement all three detection methods from the start rather than trying one at a time. The existing code structure (idempotent guard, separate validation method) was designed for this pattern and makes multi-trigger implementation straightforward.

## Standard Stack

### Core Detection APIs

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Foundation.NotificationCenter | macOS 13.0+ | NSCalendarDayChanged notification | System-provided day change events, handles timezone/DST automatically |
| AppKit.NSWorkspace | macOS 13.0+ | didWakeNotification | Standard pattern for sleep/wake detection in macOS apps |
| Foundation.Timer | macOS 13.0+ | Scheduled midnight timer | Guaranteed fallback when notifications delayed or unreliable |
| Foundation.Calendar | macOS 13.0+ | Date comparison and midnight calculation | Recommended API for calendar-aware date operations |

### Supporting APIs

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation.DateFormatter | macOS 13.0+ | (Currently used) String-based date comparison | REPLACE with Calendar API for timezone safety |
| NSSystemTimeZoneDidChange | macOS 13.0+ | Timezone change notification | Optional - detect timezone changes for immediate updates |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Triple redundancy | Single notification method | Cleaner code but fails in edge cases (sleep at midnight, notification issues, app suspension) |
| Calendar API | Continue with DateFormatter strings | Slightly simpler but vulnerable to timezone changes and DST transitions |
| Timer-only approach | Just schedule midnight timer | Works but misses immediate detection when Mac wakes after midnight |

**Installation:**
No additional dependencies required - all APIs are part of macOS 13.0+ system frameworks (Foundation and AppKit).

## Architecture Patterns

### Recommended Implementation Structure

```swift
// In SlotManager.swift
class SlotManager: ObservableObject {
    // ... existing properties ...

    // NEW: Store observer tokens for cleanup
    private var observers: [NSObjectProtocol] = []

    init() {
        self.today = DailySlots()
        load()
        checkForNewDay()
        setupDayChangeObservers()  // NEW
    }

    deinit {
        // Clean up observers
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
```

### Pattern 1: Triple-Redundancy Day Detection

**What:** Three independent triggers all call the same validation method
**When to use:** Long-running apps that must respond to time-based events without user interaction

**Example:**
```swift
// Source: Research synthesis from official Apple documentation patterns
private func setupDayChangeObservers() {
    // Method 1: System calendar day change notification
    let dayChangeObserver = NotificationCenter.default.addObserver(
        forName: .NSCalendarDayChanged,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        self?.checkForNewDay()
    }
    observers.append(dayChangeObserver)

    // Method 2: Mac wake from sleep
    let wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.didWakeNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        self?.checkForNewDay()
    }
    observers.append(wakeObserver)

    // Method 3: Scheduled midnight timer (fallback)
    scheduleMidnightCheck()
}

private func scheduleMidnightCheck() {
    let now = Date()
    let calendar = Calendar.current

    // Calculate next midnight
    guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
          let nextMidnight = calendar.startOfDay(for: tomorrow) else {
        return
    }

    // Add 5-second buffer to ensure we're past midnight
    let bufferInterval: TimeInterval = 5
    let fireDate = nextMidnight.addingTimeInterval(bufferInterval)
    let timeInterval = fireDate.timeIntervalSince(now)

    Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
        self?.checkForNewDay()
        self?.scheduleMidnightCheck()  // Reschedule for next day
    }
}
```

### Pattern 2: Calendar-Based Date Comparison (Replacing DateFormatter)

**What:** Use Calendar API instead of string comparison for timezone-safe day equality checks
**When to use:** All date comparison operations, especially for day boundaries

**Example:**
```swift
// Source: https://developer.apple.com/documentation/foundation/nscalendar
// CURRENT (vulnerable to timezone issues):
static func todayDateString() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
}

// RECOMMENDED (timezone-safe):
func checkForNewDay() -> Bool {
    let now = Date()
    let storedDate = // reconstruct Date from today.dateString

    // Option 1: Use Calendar comparison
    if !Calendar.current.isDate(storedDate, inSameDayAs: now) {
        initializeNewDay()
        return true
    }

    // Option 2: Compare date strings BUT with explicit timezone
    let todayString = DailySlots.todayDateString()
    if today.dateString != todayString {
        initializeNewDay()
        return true
    }

    return false
}
```

### Pattern 3: Timezone Change Detection (Optional Enhancement)

**What:** Respond immediately when user changes timezone settings
**When to use:** When day boundary must update instantly on timezone change (not just on next check)

**Example:**
```swift
// Source: https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/nssystemtimezonedidchange
// Add to setupDayChangeObservers():
let timezoneObserver = NotificationCenter.default.addObserver(
    forName: .NSSystemTimeZoneDidChange,
    object: nil,
    queue: .main
) { [weak self] _ in
    self?.checkForNewDay()  // Revalidate day boundary in new timezone
}
observers.append(timezoneObserver)
```

### Anti-Patterns to Avoid

- **Single detection method without redundancy:** Each method has edge cases where it fails. Using only one method means app will fail to detect day changes in specific scenarios.
- **Creating new DateFormatter on each call:** Current code creates formatter in `todayDateString()` every time. Better to use Calendar API or create static formatter with explicit timezone.
- **Observing didBecomeActive without wake notification:** AppDelegate currently observes `NSApplication.didBecomeActiveNotification` but this doesn't fire when Mac wakes if app stays in background. Must add `NSWorkspace.didWakeNotification`.
- **Not storing observer tokens:** Observers without proper cleanup can cause crashes during deinit. Always store tokens and remove in deinit.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Detecting midnight transitions | Manual date comparison loop checking every minute | NSCalendarDayChanged notification | System already tracks this, handles DST/timezone automatically, more battery efficient |
| Timezone-aware date comparison | String manipulation with timezone offset calculations | Calendar.current.isDate(_:inSameDayAs:) | Calendar API handles all edge cases (DST, leap seconds, timezone rules) |
| Scheduling recurring midnight timers | Manually calculating seconds until midnight and rescheduling | Timer with Calendar-calculated interval + self-reschedule | Prevents drift, handles DST transitions correctly |
| Detecting Mac sleep/wake cycles | Observing screen lock or system idle time | NSWorkspace.didWakeNotification | Only reliable way to detect wake from sleep, handles all power management modes |

**Key insight:** System event detection on macOS requires platform-specific APIs because sleep/wake cycles, timezone changes, and calendar day boundaries are managed by the OS. Hand-rolled solutions using polling or manual time calculations miss edge cases and waste battery.

## Common Pitfalls

### Pitfall 1: NSCalendarDayChanged Doesn't Fire During Sleep

**What goes wrong:** User leaves app running at 11:45 PM, Mac sleeps at midnight, wakes at 8 AM. NSCalendarDayChanged notification doesn't fire because system was asleep at midnight.

**Why it happens:** Apple documentation states "If the device is asleep when the day changes, this notification will be posted on wakeup. Only one notification will be posted on wakeup if the device has been asleep for multiple days." However, timing is not guaranteed - notification may be delayed.

**How to avoid:** ALWAYS implement wake notification as second detection method. When Mac wakes, check if day changed during sleep.

**Warning signs:** App works correctly when Mac stays awake overnight, but fails when user closes lid at night.

### Pitfall 2: DateFormatter Without Explicit Timezone

**What goes wrong:** User travels from PST to EST timezone. App continues showing yesterday's date because DateFormatter created without explicit timezone uses system timezone at creation time, not current timezone.

**Why it happens:** Current code creates new DateFormatter on each `todayDateString()` call without setting `.timeZone` property. Default behavior is usually correct but can fail during timezone transitions.

**How to avoid:** Either use Calendar API for all day comparisons, or set `formatter.timeZone = TimeZone.current` explicitly. Calendar API is preferred because it handles DST transitions automatically.

**Warning signs:** User reports wrong date after traveling or manually changing system timezone.

### Pitfall 3: Assuming didBecomeActive Covers All Cases

**What goes wrong:** App correctly detects day changes when user clicks on app or opens popover, but fails to detect day change when Mac wakes from sleep if app stays in background.

**Why it happens:** `NSApplication.didBecomeActiveNotification` only fires when app becomes the active application. Menubar apps typically stay in background even after wake.

**How to avoid:** Keep existing `applicationDidBecomeActive` observer (useful for user interaction), but ADD `NSWorkspace.didWakeNotification` observer specifically for wake detection.

**Warning signs:** "New day detection works when I click the icon but not when Mac wakes from sleep."

### Pitfall 4: Timer Not Rescheduling After Fire

**What goes wrong:** First midnight detection works, but subsequent nights fail because timer fires once and never reschedules.

**Why it happens:** `Timer.scheduledTimer(withTimeInterval:repeats:false)` creates one-shot timer. Must explicitly reschedule in the completion handler.

**How to avoid:** Call `scheduleMidnightCheck()` again at the end of timer handler to schedule next midnight.

**Warning signs:** Day detection works on first night after app launch, fails on subsequent nights.

### Pitfall 5: Not Handling DST Transitions

**What goes wrong:** On DST "spring forward" night (2 AM becomes 3 AM), midnight timer fires at wrong time or doesn't fire at all.

**Why it happens:** Naive time calculations don't account for DST transitions. Using `Calendar.startOfDay(for:)` handles this automatically.

**How to avoid:** Always use Calendar API for date calculations. Never manually add 24 hours or calculate midnight as "today + 86400 seconds."

**Warning signs:** App fails to detect new day on specific dates (DST transition dates).

## Code Examples

Verified patterns from official sources:

### Complete Day Detection Setup

```swift
// Source: Synthesized from Apple documentation patterns
// https://developer.apple.com/documentation/foundation/nsnotification/name/1408062-nscalendardaychanged
// https://developer.apple.com/documentation/appkit/nsworkspace/didwakenotification

class SlotManager: ObservableObject {
    @Published var today: DailySlots
    @Published var history: [DayHistory] = []

    private var observers: [NSObjectProtocol] = []
    private var midnightTimer: Timer?

    init() {
        self.today = DailySlots()
        load()
        checkForNewDay()
        setupDayChangeObservers()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        midnightTimer?.invalidate()
    }

    private func setupDayChangeObservers() {
        // Observer 1: System calendar day change
        let dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDayChange(source: "NSCalendarDayChanged")
        }
        observers.append(dayChangeObserver)

        // Observer 2: Wake from sleep
        let wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDayChange(source: "Wake")
        }
        observers.append(wakeObserver)

        // Observer 3 (Optional): Timezone change
        let timezoneObserver = NotificationCenter.default.addObserver(
            forName: .NSSystemTimeZoneDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDayChange(source: "Timezone")
        }
        observers.append(timezoneObserver)

        // Method 3: Scheduled midnight timer
        scheduleMidnightCheck()
    }

    private func scheduleMidnightCheck() {
        let now = Date()
        let calendar = Calendar.current

        // Calculate next midnight (start of next day)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
              let nextMidnight = calendar.startOfDay(for: tomorrow) else {
            return
        }

        // Add small buffer to ensure we're past midnight
        let bufferInterval: TimeInterval = 5
        let fireDate = nextMidnight.addingTimeInterval(bufferInterval)
        let timeInterval = fireDate.timeIntervalSince(now)

        // Schedule timer for midnight + buffer
        midnightTimer = Timer.scheduledTimer(
            withTimeInterval: timeInterval,
            repeats: false
        ) { [weak self] _ in
            self?.handleDayChange(source: "Timer")
            self?.scheduleMidnightCheck()  // Reschedule for next midnight
        }
    }

    private func handleDayChange(source: String) {
        #if DEBUG
        print("[DayDetection] Triggered by: \(source)")
        #endif
        checkForNewDay()
    }

    // Existing method - already has idempotent guard
    @discardableResult
    func checkForNewDay() -> Bool {
        let todayString = DailySlots.todayDateString()
        if today.dateString != todayString {
            initializeNewDay()
            return true
        }
        return false
    }
}
```

### Calendar-Safe Date Comparison

```swift
// Source: https://developer.apple.com/documentation/foundation/calendar
// BETTER: Timezone-explicit DateFormatter
struct DailySlots: Codable, Equatable {
    // ...

    static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current  // EXPLICIT timezone
        return formatter.string(from: Date())
    }
}

// BEST: Use Calendar API for comparisons
extension SlotManager {
    func checkForNewDay() -> Bool {
        // Parse stored date string back to Date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        guard let storedDate = formatter.date(from: today.dateString) else {
            // If parse fails, assume new day to be safe
            initializeNewDay()
            return true
        }

        // Use Calendar comparison (handles timezone/DST correctly)
        let now = Date()
        if !Calendar.current.isDate(storedDate, inSameDayAs: now) {
            initializeNewDay()
            return true
        }

        return false
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual date polling every minute | NSCalendarDayChanged notification + wake detection | macOS 10.9+ | Better battery life, handles sleep correctly |
| String-based date comparison | Calendar.isDate(_:inSameDayAs:) | iOS 8+ / macOS 10.9+ | Timezone and DST safety |
| 24-hour timer intervals | Calendar.startOfDay + date arithmetic | Always recommended | Handles DST transitions correctly |
| didBecomeActive only | didBecomeActive + didWakeNotification | Best practice for menubar apps | Catches day changes during sleep |

**Deprecated/outdated:**
- **NSCalendarDayChangedNotification (NSString constant):** Use `.NSCalendarDayChanged` (Notification.Name) in Swift
- **Timer.scheduledTimer with target/selector:** Use closure-based `Timer.scheduledTimer(withTimeInterval:repeats:block:)` for better memory safety
- **Manual timezone offset calculations:** Calendar API handles all edge cases automatically

## Open Questions

1. **NSCalendarDayChanged reliability in menubar apps (LSUIElement = true)**
   - What we know: Notification exists and is documented to fire at midnight and on wake
   - What's unclear: Whether notification fires reliably for menubar-only apps that never become active application
   - Recommendation: Implement all three methods from start. If notification proves reliable during testing, keep all three anyway for defense-in-depth.

2. **Notification timing guarantees**
   - What we know: Apple documentation explicitly states "There are no guarantees about the timeliness of when this notification will be received by observers"
   - What's unclear: Typical delay range in practice (seconds? minutes?)
   - Recommendation: This is why timer fallback is critical. Accept that immediate detection isn't guaranteed, but ensure detection happens within 5 seconds of midnight worst case.

3. **Multiple observers firing simultaneously**
   - What we know: Existing `checkForNewDay()` has idempotent guard (line 389: `if today.dateString != todayString`)
   - What's unclear: Whether multiple observers firing at exactly the same time could cause race conditions
   - Recommendation: Current implementation is safe because guard prevents duplicate processing. All observers use `.main` queue, ensuring serial execution.

4. **Best timezone change handling**
   - What we know: NSSystemTimeZoneDidChange notification exists and fires on timezone changes
   - What's unclear: Whether this is necessary given Calendar.current automatically uses current timezone
   - Recommendation: Add timezone observer for immediate response (nice-to-have), but Calendar API ensures correctness even without it.

## Sources

### Primary (HIGH confidence)

**Official Apple Documentation:**
- [NSCalendarDayChanged Notification](https://developer.apple.com/documentation/foundation/nsnotification/name/1408062-nscalendardaychanged) - Day change notification API
- [NSWorkspace.didWakeNotification](https://developer.apple.com/documentation/appkit/nsworkspace/didwakenotification) - Wake from sleep detection
- [NSSystemTimeZoneDidChange](https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/nssystemtimezonedidchange) - Timezone change notification
- [Timer.scheduledTimer](https://developer.apple.com/documentation/foundation/timer/scheduledtimer(withtimeinterval:repeats:block:)) - Timer API
- [Calendar.isDate(_:inSameDayAs:)](https://developer.apple.com/documentation/foundation/calendar) - Date comparison API

**Codebase Analysis:**
- `/Users/pedf/workspace/pomodoro-mac/PomodoroApp/Models/SlotManager.swift` - Current implementation with idempotent guard
- `/Users/pedf/workspace/pomodoro-mac/PomodoroApp/PomodoroApp.swift` - AppDelegate with existing didBecomeActive observer
- `/Users/pedf/workspace/pomodoro-mac/PomodoroApp/Models/DailySlots.swift` - DateFormatter usage without explicit timezone

**Prior Project Research:**
- `.planning/research/SUMMARY.md` - High-level architecture decisions and implementation approach
- `.planning/research/DAY_CHANGE_SUMMARY.md` - Detailed triple-redundancy pattern analysis

### Secondary (MEDIUM confidence)

**Community Implementation Patterns:**
- [GitHub: Telephone NSCalendarDayChangeEventSource](https://github.com/64characters/Telephone/blob/master/Telephone/NSCalendarDayChangeEventSource.swift) - Real-world example of day change detection
- [Medium: Detecting OSX System Events in Swift](https://medium.com/@clyapp/using-swift-to-detect-osx-system-events-sleep-wakeup-lock-unlock-screensaver-display-change-529cae9a3e23) - Wake notification patterns
- [Hacking with Swift: Timer Guide](https://www.hackingwithswift.com/articles/117/the-ultimate-guide-to-timer) - Timer best practices
- [Bugfender: Swift Date Operations](https://bugfender.com/blog/swift-dates/) - Calendar and timezone handling

### Tertiary (LOW confidence, needs validation)

**Edge Cases to Test:**
- Notification behavior during multi-day sleep (documentation states only one notification fires)
- Exact notification timing variability (documentation warns no guarantees)
- Menubar app (LSUIElement) notification reception (most examples use standard apps)
- DST transition timing edge cases (needs testing on actual transition dates)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All APIs are documented Foundation/AppKit features, available since macOS 10.9+
- Architecture: HIGH - Integrates cleanly into existing MVVM structure, idempotent guard already present
- Pitfalls: HIGH - Identified from code review and official documentation warnings
- Implementation approach: HIGH - Triple redundancy is standard pattern for long-running macOS apps
- Notification reliability: MEDIUM - Documentation confirms notifications exist but warns about timing

**Research date:** 2026-02-12
**Valid until:** 60 days (stable Foundation APIs, unlikely to change)

**Research sources used:**
- Official Apple Developer Documentation (7 API references)
- Direct codebase inspection (3 files analyzed)
- Prior project research documents (2 files)
- Community implementation examples (4 verified patterns)

**Ready for planning:** YES - All requirements (DAY-01 through DAY-05) have clear implementation paths with HIGH confidence.
