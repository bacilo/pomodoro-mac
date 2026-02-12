# Architecture Patterns: Day Change Detection

**Domain:** Calendar day boundary detection in menubar applications
**Researched:** 2026-02-12

## Recommended Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      SlotManager                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              checkForNewDay()                         │  │
│  │  - Compare today.dateString vs Date()                │  │
│  │  - If different: initializeNewDay()                  │  │
│  │  - Guard prevents duplicate processing               │  │
│  └──────────────────────────────────────────────────────┘  │
│                           ▲                                 │
│                           │                                 │
│                           │ (called by all triggers)        │
│            ┌──────────────┴──────────────┐                 │
│            │              │               │                 │
│  ┌─────────┴─────┐  ┌────┴──────┐  ┌─────┴────────┐       │
│  │ Notification  │  │   Wake    │  │    Timer     │       │
│  │   Observer    │  │  Observer │  │  (midnight)  │       │
│  │ .NSCalendar   │  │ didWake   │  │ auto-reschedule│      │
│  │ DayChanged    │  │Notification│  │              │       │
│  └───────────────┘  └───────────┘  └──────────────┘       │
│         ▲                 ▲                ▲                │
│         │                 │                │                │
└─────────┼─────────────────┼────────────────┼────────────────┘
          │                 │                │
          │                 │                │
  ┌───────┴────────┐  ┌─────┴─────┐  ┌──────┴──────┐
  │   Foundation   │  │ NSWorkspace│  │   Timer     │
  │ NotificationCenter│ Notification│  │  scheduled  │
  │                │  │            │  │  at midnight│
  └────────────────┘  └────────────┘  └─────────────┘
```

### Data Flow

1. **Trigger sources** (system events) fire independently
2. **All triggers** call same validation method: `checkForNewDay()`
3. **Validation method** checks if day actually changed (idempotent)
4. **If day changed**: `initializeNewDay()` saves history and creates fresh state
5. **State update** publishes changes via `@Published` properties

**Key insight:** The existing `checkForNewDay()` already provides idempotency through date comparison guard (line 389). This makes it safe to call from multiple triggers without coordination.

## Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| SlotManager | Day change logic, state management | NotificationCenter (observer), Foundation Timer (scheduler) |
| checkForNewDay() | Validation gate - determines if day actually changed | today.dateString property, Date() for current date |
| initializeNewDay() | State transition - save history, create new day | DailySlots model, history array, defaultSlotNames template |
| NotificationCenter | System event distribution | SlotManager (via registered observers) |
| Timer | Scheduled midnight trigger | SlotManager (via closure callback) |
| Calendar.current | Calendar calculations, timezone handling | Used by all components for date comparisons |

### Integration Points

**Existing integration:** `AppDelegate.applicationDidBecomeActive` (line 334-336) already calls `checkForNewDay()`. This pattern will be extended to other triggers.

**New integrations needed:**
1. `SlotManager.init()` adds observers for calendar day change and wake notifications
2. `SlotManager.init()` schedules first midnight timer
3. Timer reschedules itself after each fire

## Patterns to Follow

### Pattern 1: Observer Registration in Init
**What:** Register notification observers when SlotManager initializes
**When:** App launch, before any timer logic runs
**Example:**
```swift
class SlotManager: ObservableObject {
    private var observers: [NSObjectProtocol] = []
    private var midnightTimer: Timer?

    init() {
        self.today = DailySlots()
        load()
        checkForNewDay()

        // Register observers
        setupDayChangeObservers()
        scheduleMidnightCheck()
    }

    private func setupDayChangeObservers() {
        // Calendar day changed notification
        let dayObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkForNewDay()
        }
        observers.append(dayObserver)

        // System wake notification
        let wakeObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkForNewDay()
        }
        observers.append(wakeObserver)
    }

    deinit {
        // Clean up observers
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        midnightTimer?.invalidate()
    }
}
```

**Why this pattern:**
- Block-based observer API automatically captures weak self (prevents retain cycle)
- Storing observer tokens allows proper cleanup in deinit
- Main queue ensures thread safety with @Published properties
- Follows existing pattern in AppDelegate (lines 58-63)

### Pattern 2: Self-Rescheduling Midnight Timer
**What:** Timer that fires at next midnight and automatically reschedules
**When:** Initial schedule in init, reschedule after each fire
**Example:**
```swift
private func scheduleMidnightCheck() {
    let calendar = Calendar.current
    let now = Date()

    // Calculate next midnight
    guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
          let nextMidnight = calendar.date(
            from: calendar.dateComponents([.year, .month, .day], from: tomorrow)
          ) else {
        return
    }

    // Add 5 seconds buffer to ensure we're past midnight
    let fireDate = nextMidnight.addingTimeInterval(5)
    let timeUntilFire = max(1, fireDate.timeIntervalSince(now))

    // Schedule one-time timer
    midnightTimer?.invalidate()
    midnightTimer = Timer.scheduledTimer(
        withTimeInterval: timeUntilFire,
        repeats: false
    ) { [weak self] _ in
        self?.checkForNewDay()
        self?.scheduleMidnightCheck() // Reschedule for tomorrow
    }
}
```

**Why this pattern:**
- One-time timer with explicit reschedule (clearer than repeating with dynamic interval)
- 5-second buffer avoids edge case of firing slightly before midnight
- Calendar API handles timezone and DST automatically
- `max(1, ...)` prevents negative intervals if calculation has issues

### Pattern 3: Idempotent State Update
**What:** checkForNewDay() can be called multiple times safely
**When:** Every detection method calls it - no coordination needed
**Example:**
```swift
@discardableResult
func checkForNewDay() -> Bool {
    let todayString = DailySlots.todayDateString()

    // Guard clause - early exit if already on correct day
    if today.dateString == todayString {
        return false // No change
    }

    // Day has changed - update state
    initializeNewDay()
    return true // Changed
}
```

**Why this pattern:**
- Guard clause at top prevents duplicate processing
- State update happens only once even if called from multiple triggers
- Return value allows logging which trigger actually caused change (for debugging)
- Already implemented in current codebase (line 387-394)

### Pattern 4: Calendar-Aware Date Comparison
**What:** Use Calendar API instead of direct Date comparison
**When:** Any date comparison that cares about day boundaries
**Example:**
```swift
// GOOD: Calendar-aware day comparison
let calendar = Calendar.current
let isToday = calendar.isDate(someDate, inSameDayAs: Date())

// ALTERNATIVE: Comparison at day granularity
let isSameDay = calendar.compare(
    date1, to: date2,
    toGranularity: .day
) == .orderedSame

// GOOD: Get start of day (midnight)
let midnight = calendar.startOfDay(for: Date())

// BAD: Direct date comparison (breaks with timezone changes)
let isLater = date1 > date2 // Don't use for day boundaries
```

**Why this pattern:**
- Respects user's current timezone automatically
- Handles DST transitions correctly
- Works across timezone changes without modification
- More readable - intent is clear

## Anti-Patterns to Avoid

### Anti-Pattern 1: Polling with Frequent Timer
**What:**
```swift
// BAD: Check every minute
Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
    checkForNewDay()
}
```
**Why bad:**
- 1440 unnecessary checks per day (only need 1)
- Prevents app nap and energy optimization
- CPU cycles wasted on no-op checks
**Instead:** Use notification-based or single midnight timer

### Anti-Pattern 2: Forgetting to Reschedule Timer
**What:**
```swift
Timer.scheduledTimer(withTimeInterval: secondsUntilMidnight, repeats: false) { _ in
    checkForNewDay()
    // MISSING: scheduleMidnightCheck()
}
```
**Why bad:**
- Works first day, fails forever after
- Subtle bug that only appears after 24+ hours
**Instead:** Always reschedule in timer callback

### Anti-Pattern 3: Manual Timezone Handling
**What:**
```swift
// BAD: Hardcoded timezone
let utc = TimeZone(identifier: "UTC")!
var calendar = Calendar.current
calendar.timeZone = utc
let midnight = calendar.startOfDay(for: Date())
```
**Why bad:**
- User is not necessarily in UTC
- Breaks when traveling
- Calendar.current already knows system timezone
**Instead:** Trust `Calendar.current` without modification

### Anti-Pattern 4: Not Observing Wake Notifications
**What:** Only using `.NSCalendarDayChanged` without wake detection
**Why bad:**
- Notification doesn't fire during sleep
- Most Macs sleep overnight when day changes
- Results in stale data every morning
**Instead:** Always add `NSWorkspace.didWakeNotification` observer

### Anti-Pattern 5: Coordinator/Arbiter Between Triggers
**What:**
```swift
// BAD: Complex coordination
var lastTriggerTime: Date?
func handleDayChange(from source: TriggerSource) {
    guard let last = lastTriggerTime,
          Date().timeIntervalSince(last) > 60 else {
        return // Debounce
    }
    lastTriggerTime = Date()
    checkForNewDay()
}
```
**Why bad:**
- Unnecessary complexity
- Introduces timing bugs (what if legitimate trigger within 60s?)
- checkForNewDay() already has guard clause
**Instead:** Let each trigger call checkForNewDay() directly - guard handles deduplication

## Scalability Considerations

| Concern | At 100 users | At 10K users | At 1M users |
|---------|--------------|--------------|-------------|
| Observer memory | ~100 bytes/user (negligible) | ~1MB total (negligible) | Not applicable (single-user desktop app) |
| Timer overhead | 1 timer/app instance | N/A (desktop not cloud) | N/A |
| Notification processing | Instant (milliseconds) | N/A | N/A |
| Calendar API calls | 3-6 per day (cached by system) | N/A | N/A |

**Note:** This is a menubar desktop app, not a web service. Scalability concerns are per-app-instance, not across users. All approaches have negligible overhead for single user.

**Real concern:** Memory safety across years of continuous running:
- Observer tokens must be cleaned up in deinit
- Timer must be invalidated to break retain cycle
- No accumulating state in detection logic (all stateless)

## Testing Strategy

### Unit Tests
```swift
// Test day change detection logic
func testCheckForNewDay_SameDay_ReturnsFalse() {
    let manager = SlotManager()
    let firstCheck = manager.checkForNewDay()
    let secondCheck = manager.checkForNewDay()
    XCTAssertFalse(secondCheck, "Should not trigger on same day")
}

// Test idempotency
func testCheckForNewDay_MultipleCalls_OnlyInitializesOnce() {
    let manager = SlotManager()
    // Advance system date somehow (or inject date provider)
    manager.checkForNewDay()
    manager.checkForNewDay()
    manager.checkForNewDay()
    // Verify only one history entry created
}
```

### Integration Tests
- Observer registration test (verify observers added in init)
- Timer scheduling test (verify timer scheduled with correct interval)
- Wake notification test (simulate wake, verify day check called)

### Manual Tests
- Overnight test (leave app running, check in morning)
- Sleep test (sleep Mac before midnight, wake after)
- Timezone test (change system timezone, verify midnight changes)
- Multi-day test (run continuously for 7 days)

## Implementation Checklist

- [ ] Add notification observer setup method
- [ ] Add midnight timer scheduling method
- [ ] Store observer tokens for cleanup
- [ ] Implement deinit to clean up observers and timer
- [ ] Add logging (debug only) to track which trigger fires
- [ ] Test each trigger method independently
- [ ] Test all three triggers together (no conflicts)
- [ ] Verify existing checkForNewDay() guard works correctly
- [ ] Add unit tests for observer registration
- [ ] Add integration test for overnight scenario

## Sources

- Current implementation: `/Users/pedf/workspace/pomodoro-mac/PomodoroApp/Models/SlotManager.swift`
- Existing pattern reference: `/Users/pedf/workspace/pomodoro-mac/PomodoroApp/PomodoroApp.swift` (AppDelegate observer pattern)
- Foundation NotificationCenter patterns (training data knowledge)
- Timer scheduling patterns (training data knowledge)
- Calendar API usage (training data knowledge)

**Note:** Architecture designed to integrate with existing codebase patterns. All new code follows established conventions (ObservableObject, @Published, NotificationCenter usage already present).
