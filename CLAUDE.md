# PomodoroApp - Claude Code Guidelines

A macOS menubar Pomodoro timer app built with SwiftUI.

## Project Overview

- **Stack**: Swift 5.9+, SwiftUI, macOS 13.0+
- **Pattern**: MVVM (Model-View-ViewModel)
- **App Type**: Menubar-only (LSUIElement = true)

## Commands

```bash
# Build
xcodebuild build -project PomodoroApp.xcodeproj -scheme PomodoroApp -destination 'platform=macOS'

# Test (ALWAYS run before committing)
xcodebuild test -project PomodoroApp.xcodeproj -scheme PomodoroApp -destination 'platform=macOS'

# Open in Xcode
open PomodoroApp.xcodeproj
```

## Architecture

```
PomodoroApp/
├── PomodoroApp.swift      # Entry point, MenuBarExtra setup
├── Models/                # Data structures, enums
├── ViewModels/            # Business logic, state management
├── Views/                 # SwiftUI views
└── Resources/             # Assets
```

Key files:
- Timer logic: `ViewModels/PomodoroViewModel.swift`
- State machine: `Models/TimerState.swift`
- Persistence: `Models/Settings.swift`, `Models/Statistics.swift`

## Development Workflow

### Test-First Development

**IMPORTANT**: Write tests BEFORE implementing features.

1. Create failing test in `PomodoroAppTests/`
2. Verify test fails (confirms it tests something real)
3. Write minimal code to pass
4. Refactor while keeping tests green
5. Run full test suite before committing

### Adding Features

1. Identify which layer needs changes (Model → ViewModel → View)
2. Write tests for new behavior first
3. Implement in the appropriate layer
4. Update `docs/` if architecture changes

### Code Conventions

- Use `@MainActor` for ViewModels
- Use `@Published` for observable state
- Use `@AppStorage` for user preferences
- Keep Views thin - logic belongs in ViewModels
- Test names: `test<Method>_<Scenario>_<Expected>()`

## Testing

Tests live in `PomodoroAppTests/`. Current coverage:

| File | Tests |
|------|-------|
| `TimerStateTests.swift` | Enums, display names, codable |
| `SettingsTests.swift` | Duration conversions, defaults |
| `StatisticsTests.swift` | Recording, aggregation, persistence |
| `PomodoroViewModelTests.swift` | Timer state, start/pause/reset |

Run tests: `Cmd+U` in Xcode or `./Scripts/test.sh`

## Documentation

- `docs/architecture.md` - System design, data flow
- `docs/testing.md` - TDD workflow, test patterns

Update docs when:
- Adding new components or changing data flow
- Introducing new patterns or conventions
- Changing the persistence strategy

## Common Tasks

### Add a new setting
1. Add `@AppStorage` property to `Settings.swift`
2. Write test in `SettingsTests.swift`
3. Add UI control in `SettingsView.swift`
4. Use in `PomodoroViewModel` if needed

### Add a new timer state
1. Add case to `TimerState` enum
2. Update `displayName`, `icon`, `menuBarIcon`
3. Handle in `PomodoroViewModel.transitionToNextState()`
4. Update `TimerView` stroke colors

### Modify statistics tracking
1. Update `Statistics.swift` model
2. Add tests for new calculations
3. Update `StatsView.swift` display
