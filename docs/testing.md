# Testing Guide

## Test-First Development

This project follows test-first development (TDD). When adding new features:

1. **Write failing tests first** - Define expected behavior before implementation
2. **Run tests to confirm failure** - Verify tests actually test something
3. **Implement the feature** - Write minimal code to pass tests
4. **Refactor** - Clean up while keeping tests green

## Running Tests

### Via Xcode
```
Cmd + U  # Run all tests
```

### Via Command Line
```bash
xcodebuild test \
  -project PomodoroApp.xcodeproj \
  -scheme PomodoroApp \
  -destination 'platform=macOS'
```

### Quick Script
```bash
./Scripts/test.sh
```

## Test Structure

```
PomodoroAppTests/
├── TimerStateTests.swift      # Model: TimerState enum
├── SettingsTests.swift        # Model: Settings persistence
├── StatisticsTests.swift      # Model: Statistics tracking
└── PomodoroViewModelTests.swift # ViewModel: Timer logic
```

## Test Categories

### Unit Tests (Current)
- Model behavior and data transformations
- ViewModel state management
- No external dependencies

### Integration Tests (Future)
- Notification delivery
- UserDefaults persistence across launches
- Full timer cycles

### UI Tests (Future)
- Menu bar interaction
- Settings changes reflect in timer
- Statistics display accuracy

## Writing Tests

### Naming Convention
```swift
func test<MethodOrBehavior>_<Scenario>_<ExpectedResult>()

// Examples:
func testStartWork_FromIdle_SetsStateToWork()
func testProgress_HalfwayThrough_ReturnsFiftyPercent()
```

### Test Setup
```swift
override func setUp() async throws {
    // Clear UserDefaults to avoid test pollution
    UserDefaults.standard.removeObject(forKey: "key")

    // Create fresh instances
    viewModel = PomodoroViewModel()
}

override func tearDown() async throws {
    viewModel = nil
    // Clean up any persisted state
}
```

### Async/MainActor Tests
```swift
@MainActor
final class PomodoroViewModelTests: XCTestCase {
    // Tests run on main actor for ViewModel

    func testSomething() {
        // No await needed for synchronous operations
    }
}
```

## Coverage Goals

| Component | Target Coverage |
|-----------|-----------------|
| Models | 90%+ |
| ViewModel | 80%+ |
| Views | UI tests only |

## Common Test Patterns

### Testing State Transitions
```swift
func testStateTransition() {
    // Given: Initial state
    XCTAssertEqual(viewModel.timerState, .idle)

    // When: Action
    viewModel.startWork()

    // Then: Expected state
    XCTAssertEqual(viewModel.timerState, .work)
}
```

### Testing Persistence
```swift
func testPersistence() {
    // Given: Save data
    statistics.recordCompletedPomodoro(durationMinutes: 25)

    // When: Create new instance (simulates app restart)
    let newStatistics = Statistics()

    // Then: Data persisted
    XCTAssertEqual(newStatistics.todayStats.completedPomodoros, 1)
}
```
