# Coding Conventions

**Analysis Date:** 2026-02-12

## Naming Patterns

**Files:**
- PascalCase for files containing ViewModels, Views, Models: `PomodoroViewModel.swift`, `TimerView.swift`, `Settings.swift`
- PascalCase for Test files: `PomodoroViewModelTests.swift`, `SettingsTests.swift`
- Files group related functionality by layer: Models, ViewModels, Views directories

**Functions:**
- camelCase for function names: `startWork()`, `pauseTimer()`, `setProgress()`
- Action functions use verb-first pattern: `toggle`, `advance`, `record`, `transition`
- Private helper functions prefixed with underscore convention avoided; use `private func` modifier instead
- Getter functions omit "get" prefix: `progress` not `getProgress()`

**Variables:**
- camelCase for properties: `timeRemaining`, `isRunning`, `timerState`
- Boolean properties prefix with `is` or similar: `isRunning`, `isDragging`, `hasIncompleteSlots`
- Private properties use `private` modifier: `private var timer`, `private var sessionStartTime`
- Published properties use `@Published` annotation in ViewModels
- Stored preferences use `@AppStorage` for UserDefaults-backed properties: `@AppStorage("workDuration")`

**Types:**
- PascalCase for enums: `TimerState`, `Tab`, `CompletionSound`
- PascalCase for structs: `DailyStats`, `TimerSession`, `DailySlots`, `Slot`
- PascalCase for classes: `PomodoroViewModel`, `Statistics`, `Settings`
- Enum cases use camelCase: `.idle`, `.work`, `.shortBreak`, `.longBreak`

## Code Style

**Formatting:**
- 4-space indentation (standard Swift)
- Line breaks between logical sections with `// MARK: - Section Name` comments
- Spacing around operators and in function arguments follows standard Swift style
- No explicit line length limit detected; follows Apple's SwiftUI conventions

**Linting:**
- No external linter configured (no .swiftformat, eslintrc, etc.)
- Follows Swift formatting conventions by convention
- Xcode's built-in formatting used during development

**Access Control:**
- Private implementation details marked with `private` keyword
- Public APIs unmarked (implicit `internal`)
- ViewModels marked with `@MainActor` for thread safety: `@MainActor class PomodoroViewModel`

## Import Organization

**Order:**
1. Foundation (core framework): `import Foundation`
2. UI frameworks: `import SwiftUI`, `import AppKit`, `import UserNotifications`, `import Combine`
3. Test utilities: `import XCTest` (in tests)
4. App module: `@testable import PomodoroApp` (in tests)

**Path Aliases:**
- Not used; imports use full module name `PomodoroApp`

## Error Handling

**Patterns:**
- No explicit error types defined; uses guard statements for validation
- Try-catch used for Codable operations in Statistics and SlotManager persistence
- Silent failures in error handlers (e.g., `try?` for notification requests)
- Guard statements with early returns for state validation: `guard timerState != .idle else { return }`
- Optional chaining used for optional properties: `timer?.invalidate()`

**Example:**
```swift
// From PomodoroViewModel.swift
private func requestNotificationPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
}
```

## Logging

**Framework:** Console via print (implicit in debug sessions)

**Patterns:**
- No explicit logging framework used
- Debug prints not observed in production code
- Assertions not used for runtime validation

## Comments

**When to Comment:**
- Section markers: `// MARK: - Section Name` used extensively to organize code into logical groups
- Complex calculations: Brief explanations of mathematical operations (e.g., angle calculations in `DraggableHandle`)
- State transitions: Comments documenting why a state change occurs

**JSDoc/TSDoc:**
- Documentation comments use triple-slash for public APIs: `/// [description]`
- Doc comments used on types and public methods, e.g., `Statistics.updateDayCount()`, `SlotManager.markSlotIncomplete()`

**Example from Statistics.swift:**
```swift
/// Update the completed count for a specific day (called when history is modified)
func updateDayCount(dateString: String, completedCount: Int) { }

/// Remove a day's stats entirely
func removeDay(dateString: String) { }
```

## Function Design

**Size:**
- Functions kept small and focused (typically 10-30 lines)
- Complex calculations (e.g., drag gesture angle conversion) kept inline with explanatory comments
- Computed properties used for derived state: `var progress`, `var timeRemainingFormatted`, `var menuBarTitle`

**Parameters:**
- Single responsibility per function
- Parameters passed directly, no parameter objects unless modeling data
- Trailing closures used for callbacks: `onProgressChange: { newProgress in ... }`

**Return Values:**
- Computed properties return derived values implicitly
- Methods modify state in-place and save via `save()` call
- Guard statements provide early returns for invalid states

**Example from PomodoroViewModel:**
```swift
var progress: Double {
    guard timerState != .idle else { return 0 }
    let total = settings.duration(for: timerState)
    guard total > 0 else { return 0 }
    return Double(total - timeRemaining) / Double(total)
}
```

## Module Design

**Exports:**
- All public types and functions are implicitly exported (no explicit export syntax in Swift)
- Structs used for data models (immutable semantics): `DailyStats`, `TimerSession`, `Slot`
- Classes used for ViewModels and Services with mutable state: `PomodoroViewModel`, `Statistics`, `SlotManager`
- Views defined as structs following SwiftUI conventions

**Barrel Files:**
- Not used; imports reference files directly
- Each file has clear single responsibility

**MVVM Pattern:**
- Models layer (`Models/`): Data structures, enums, state machines (TimerState, Statistics, Settings)
- ViewModels layer (`ViewModels/`): Business logic, state management, orchestration (PomodoroViewModel)
- Views layer (`Views/`): UI rendering, event handling, no business logic (MenuBarView, TimerView, SettingsView)
- Clear dependency direction: Views → ViewModels → Models

---

*Convention analysis: 2026-02-12*
