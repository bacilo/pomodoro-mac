# Testing Patterns

**Analysis Date:** 2026-02-12

## Test Framework

**Runner:**
- XCTest (Apple's native framework)
- Config: Xcode project (`PomodoroApp.xcodeproj`)

**Assertion Library:**
- XCTest assertions: `XCTAssertEqual`, `XCTAssertTrue`, `XCTAssertFalse`, `XCTAssertGreaterThan`, `XCTAssertLessThan`, `XCTAssertGreaterThanOrEqual`

**Run Commands:**
```bash
# Run all tests in Xcode
Cmd+U

# Run from command line
xcodebuild test -project PomodoroApp.xcodeproj -scheme PomodoroApp -destination 'platform=macOS'

# View test results
xcodebuild test ... # outputs to console
```

## Test File Organization

**Location:**
- Co-located: Tests live in separate `PomodoroAppTests/` directory
- File structure mirrors main codebase: One test file per model/component being tested

**Naming:**
- Pattern: `[ComponentName]Tests.swift`
- Examples: `PomodoroViewModelTests.swift`, `SettingsTests.swift`, `TimerStateTests.swift`, `StatisticsTests.swift`, `SlotManagerTests.swift`

**Structure:**
```
PomodoroAppTests/
├── TimerStateTests.swift          # Enum tests
├── SettingsTests.swift             # User preferences
├── StatisticsTests.swift           # Data aggregation & persistence
├── PomodoroViewModelTests.swift    # Core business logic
└── SlotManagerTests.swift          # Slot management
```

## Test Structure

**Suite Organization:**
```swift
final class PomodoroViewModelTests: XCTestCase {
    var viewModel: PomodoroViewModel!
    var settings: Settings!
    var statistics: Statistics!
    var slotManager: SlotManager!

    override func setUp() async throws {
        try await super.setUp()
        // Initialize test fixtures
        settings = Settings()
        viewModel = PomodoroViewModel(settings: settings, statistics: statistics, slotManager: slotManager)
    }

    override func tearDown() async throws {
        // Cleanup
        viewModel = nil
        try await super.tearDown()
    }

    // MARK: - Test Category
    func testFeatureBehavior() {
        // Arrange
        viewModel.startWork()

        // Act
        viewModel.pause()

        // Assert
        XCTAssertFalse(viewModel.isRunning)
    }
}
```

**Patterns:**
- setUp: Clears UserDefaults, initializes fresh objects before each test
- tearDown: Clears state and UserDefaults after each test to prevent interference
- Assertion pattern: Direct assertions on state properties
- Group tests by feature with `// MARK: - Category` comments

**Examples:**

Test initialization with cleanup (from `PomodoroViewModelTests.swift`):
```swift
override func setUp() async throws {
    try await super.setUp()
    UserDefaults.standard.removeObject(forKey: "pomodoroStatistics")
    UserDefaults.standard.removeObject(forKey: "pomodoroSessions")
    UserDefaults.standard.removeObject(forKey: "pomodoroSlots")

    settings = Settings()
    statistics = Statistics()
    slotManager = SlotManager()
    viewModel = PomodoroViewModel(settings: settings, statistics: statistics, slotManager: slotManager)
}
```

Test naming pattern (from `PomodoroViewModelTests.swift`):
```swift
func testStartWork()  // Simple behavior
func testToggleFromIdle()  // Specific scenario
func testSetProgressClampsValues()  // Boundary condition
func testCompleteEarly_AdvancesSlot()  // Integration test with underscore separator
```

## Mocking

**Framework:** Not used explicitly; manual test doubles via dependency injection

**Patterns:**
Tests pass mock/test instances of dependencies into constructors:
```swift
// Real dependencies injected
viewModel = PomodoroViewModel(settings: settings, statistics: statistics, slotManager: slotManager)

// Allows testing ViewModel behavior with controlled state
settings.workDuration = 25
statistics.recordCompletedPomodoro(durationMinutes: 25)
```

**What to Mock:**
- UserDefaults: Cleared in setUp/tearDown, not mocked
- Dependencies: Pass test instances with known state
- External services: No external service calls in codebase

**What NOT to Mock:**
- UserDefaults: Interact with real UserDefaults (with cleanup)
- Internal models: Create real instances
- Computed properties: Test directly without mocking
- Framework behaviors: Use real Timer (though timing-sensitive tests may be unreliable)

## Fixtures and Factories

**Test Data:**
```swift
// From TimerStateTests.swift - iterating over all cases
for state in [TimerState.idle, .work, .shortBreak, .longBreak] {
    let data = try encoder.encode(state)
    let decoded = try decoder.decode(TimerState.self, from: data)
    XCTAssertEqual(decoded, state)
}

// From StatisticsTests.swift - creating test session
let session = TimerSession(
    state: .work,
    startTime: Date(),
    endTime: Date().addingTimeInterval(1500),
    completed: true
)
```

No dedicated fixture files; test data created inline in test methods. Default values handled by model initializers.

**Location:**
- Inline in test methods
- No factories or builders used
- Models provide default initializers: `DailyStats()`, `Settings()`, `TimerSession(...)`

## Coverage

**Requirements:** No explicit coverage requirements configured

**View Coverage:**
```bash
# Coverage tracking via Xcode
# In Xcode: Product → Scheme → Edit Scheme → Test → Options → Code Coverage (checkbox)
```

## Test Types

**Unit Tests:**
- Scope: Individual components in isolation (ViewModels, Models, Services)
- Approach: Arrange-Act-Assert with dependency injection
- Examples: `testStartWork()`, `testDurationForWorkState()`, `testRecordCompletedPomodoro()`

**Integration Tests:**
- Scope: Multiple components interacting (ViewModel with Statistics and SlotManager)
- Approach: Wire dependencies together, test workflows
- Examples: `testCompleteEarly_AdvancesSlot()`, `testCompletedPomodoros_SyncsWithSlotManager()`

**E2E Tests:**
- Framework: Not used
- Reason: App is menubar-only; UI testing would require XCUITest (not implemented)
- Manual testing via simulator/device

## Common Patterns

**Async Testing:**
```swift
// From PomodoroViewModelTests.swift - async setUp/tearDown
override func setUp() async throws {
    try await super.setUp()
    // setup code
}

// Note: Most tests don't use async/await; only tearDown/setUp in MainActor contexts
```

**Error Testing:**
```swift
// Try-catch patterns for Codable
func testTimerStateEncodingDecoding() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let data = try encoder.encode(TimerState.work)
    let decoded = try decoder.decode(TimerState.self, from: data)
    XCTAssertEqual(decoded, .work)
}
```

**State Transition Testing:**
```swift
// From PomodoroViewModelTests.swift
func testSkipToLongBreakAfterEnoughPomodoros() {
    for _ in 0..<settings.pomodorosBeforeLongBreak {
        slotManager.advanceCompletion()
    }
    viewModel.startWork()
    viewModel.skip()

    XCTAssertEqual(viewModel.timerState, .longBreak)
}
```

**Boundary Testing:**
```swift
// From PomodoroViewModelTests.swift
func testSetProgressClampsValues() {
    viewModel.startWork()
    viewModel.pause()

    viewModel.setProgress(1.5)  // Over 100%
    XCTAssertEqual(viewModel.timeRemaining, 0)

    viewModel.timeRemaining = settings.workDurationSeconds
    viewModel.setProgress(-0.5)  // Negative
    XCTAssertEqual(viewModel.timeRemaining, settings.workDurationSeconds)
}
```

**Persistence Testing:**
```swift
// From StatisticsTests.swift
func testStatisticsPersistence() {
    statistics.recordCompletedPomodoro(durationMinutes: 25)

    // Create new instance to test loading
    let newStatistics = Statistics()

    XCTAssertEqual(newStatistics.todayStats.completedPomodoros, 1)
}
```

## Test Coverage Summary

| File | Test File | Tests | Focus |
|------|-----------|-------|-------|
| `Models/TimerState.swift` | `TimerStateTests.swift` | 11 | Enum display names, icons, Codable |
| `Models/Settings.swift` | `SettingsTests.swift` | 10 | Duration conversions, defaults |
| `Models/Statistics.swift` | `StatisticsTests.swift` | 11 | Recording, aggregation, persistence |
| `ViewModels/PomodoroViewModel.swift` | `PomodoroViewModelTests.swift` | 35+ | State machine, transitions, formatting |
| `Models/SlotManager.swift` | `SlotManagerTests.swift` | 35+ | Slot CRUD, completion tracking, persistence |

---

*Testing analysis: 2026-02-12*
