# Codebase Structure

**Analysis Date:** 2026-02-12

## Directory Layout

```
pomodoro-mac/
├── PomodoroApp/                 # Main app source code
│   ├── PomodoroApp.swift        # Entry point and AppDelegate
│   ├── Models/                  # Data structures and business logic
│   │   ├── TimerState.swift     # Pomodoro cycle state enum
│   │   ├── Slot.swift           # Single task slot (id + name)
│   │   ├── DailySlots.swift     # Today's slots + completion tracking
│   │   ├── Settings.swift       # User preferences (@AppStorage)
│   │   ├── Statistics.swift     # Daily stats and session history
│   │   └── SlotManager.swift    # Slot lifecycle and persistence
│   ├── ViewModels/              # State management and business logic
│   │   └── PomodoroViewModel.swift  # Timer orchestration (@MainActor)
│   ├── Views/                   # SwiftUI components
│   │   ├── MenuBarView.swift    # Tab coordinator and placeholder prompts
│   │   ├── TimerView.swift      # Timer circle, progress, controls
│   │   ├── TimerView+Controls.swift  # Button definitions
│   │   ├── TimerView+Circle.swift    # Visual components
│   │   ├── DraggableHandle.swift # Draggable progress indicator
│   │   ├── PomodoroDotsView.swift    # Completed count indicator
│   │   ├── SlotsView.swift      # Slot list and management
│   │   ├── SlotRowView.swift    # Individual slot row
│   │   ├── StatsView.swift      # Statistics dashboard
│   │   ├── HistoryView.swift    # Past day history
│   │   ├── SettingsView.swift   # Preferences UI
│   │   ├── SlotTemplatesView.swift  # Template configuration
│   │   └── PlaceholderPromptView.swift # Template placeholder input
│   └── Resources/               # Assets
│       ├── Assets.xcassets/     # App icon and images
│       └── SourceAssets/        # Source design files
├── PomodoroAppTests/            # Unit and integration tests
│   ├── TimerStateTests.swift    # Enum codability, display names
│   ├── SettingsTests.swift      # Duration conversions, defaults
│   ├── StatisticsTests.swift    # Recording and aggregation
│   ├── SlotManagerTests.swift   # Slot lifecycle, persistence
│   └── PomodoroViewModelTests.swift  # Timer logic, state transitions
├── Scripts/                     # Build and test scripts
├── docs/                        # Documentation
├── PomodoroApp.xcodeproj/       # Xcode project configuration
├── README.md                    # Project overview
├── CLAUDE.md                    # Development guidelines
└── .planning/                   # GSD planning artifacts (generated)
```

## Directory Purposes

**PomodoroApp/**
- Purpose: All application source code
- Contains: Models, ViewModels, Views, Resources
- Key files: `PomodoroApp.swift` (entry point), `ViewModels/PomodoroViewModel.swift` (timer logic)

**PomodoroApp/Models/**
- Purpose: Data structures, state machines, persistence logic
- Contains: Enums (TimerState), structs (Slot, DailySlots, DailyStats), managers (SlotManager, Statistics), configuration (Settings)
- Key files:
  - `TimerState.swift` - phase enum with UI properties
  - `SlotManager.swift` - slot lifecycle and daily reset logic
  - `Statistics.swift` - pomodoro tracking
  - `Settings.swift` - user preferences

**PomodoroApp/ViewModels/**
- Purpose: Business logic, state management, UI coordination
- Contains: PomodoroViewModel (timer orchestration, notifications, state transitions)
- Key files: `PomodoroViewModel.swift`

**PomodoroApp/Views/**
- Purpose: SwiftUI user interface components
- Contains: Composed views for timer, slots, stats, settings; helper views for controls and indicators
- Key files:
  - `MenuBarView.swift` - tab navigation, placeholder prompts
  - `TimerView.swift` - main timer display with circle and controls
  - `SlotsView.swift` - daily task list management
  - `StatsView.swift` - statistics dashboard
  - `SettingsView.swift` - preferences

**PomodoroApp/Resources/Assets.xcassets/**
- Purpose: App icon, images, color sets
- Generated: Yes (by Xcode)
- Committed: Yes

**PomodoroAppTests/**
- Purpose: Unit and integration tests for all models and view models
- Contains: Test files matching production code structure
- Key files: SlotManagerTests (most comprehensive), PomodoroViewModelTests, StatisticsTests

## Key File Locations

**Entry Points:**
- `PomodoroApp/PomodoroApp.swift` (lines 5-24): @main entry point, App struct with WindowGroup
- `PomodoroApp/PomodoroApp.swift` (lines 26-337): AppDelegate with status item, popover, menu management

**Core Timer Logic:**
- `PomodoroApp/ViewModels/PomodoroViewModel.swift` (lines 132-164): startTimer(), tick(), timerCompleted()

**State Machine:**
- `PomodoroApp/Models/TimerState.swift`: Enum defining .idle, .work, .shortBreak, .longBreak

**Slot Management:**
- `PomodoroApp/Models/SlotManager.swift`: Slot CRUD, template application, new day detection, persistence
- `PomodoroApp/Models/DailySlots.swift`: Slot array + completion count

**Persistence:**
- `PomodoroApp/Models/Settings.swift` (lines 24-33): @AppStorage properties (durations, auto-start, sounds)
- `PomodoroApp/Models/SlotManager.swift` (lines 307-361): UserDefaults encode/decode for slots and history
- `PomodoroApp/Models/Statistics.swift` (lines 127-147): UserDefaults encode/decode for stats

**Notifications & Sounds:**
- `PomodoroApp/ViewModels/PomodoroViewModel.swift` (lines 216-258): requestNotificationPermission(), sendNotification(), playCompletionSound()

**Menubar Display:**
- `PomodoroApp/PomodoroApp.swift` (lines 110-254): updateStatusButton(), updateStatusButtonAppearance(), blink timer, marquee timer

## Naming Conventions

**Files:**
- ViewModels: `{Feature}ViewModel.swift` (e.g., PomodoroViewModel.swift)
- Views: `{Feature}View.swift` (e.g., TimerView.swift, SettingsView.swift)
- Models: `{Entity}.swift` (e.g., Slot.swift, Settings.swift)
- Tests: `{Feature}Tests.swift` (e.g., PomodoroViewModelTests.swift)

**Directories:**
- `PomodoroApp/{Models,ViewModels,Views,Resources}/` - Organized by MVVM layer
- `PomodoroAppTests/` - Test files at same level as main app code

**Classes/Structs/Enums:**
- PascalCase (e.g., TimerState, SlotManager, MenuBarView)

**Functions:**
- camelCase (e.g., startWork(), advanceCompletion(), updateStatusButton())

**Variables/Properties:**
- camelCase (e.g., timeRemaining, isRunning, completedPomodoros)
- @Published for reactive properties
- @AppStorage for persistent preferences
- @ObservedObject to subscribe to parent ViewModel/Model

**Constants:**
- camelCase for local constants within functions
- ALL_CAPS for logical constants (e.g., marqueeMaxChars = 10 as property, not constant)

## Where to Add New Code

**New Timer Feature (e.g., pause/resume/skip):**
- Method in: `PomodoroApp/ViewModels/PomodoroViewModel.swift` (add public function)
- Tests in: `PomodoroAppTests/PomodoroViewModelTests.swift` (add test_<Feature>_<Scenario>_<Expected>)
- UI trigger in: `PomodoroApp/Views/TimerView.swift` (add Button in controlButtons)

**New Slot/Template Feature (e.g., slot templates, placeholders):**
- Logic in: `PomodoroApp/Models/SlotManager.swift` (add method)
- Tests in: `PomodoroAppTests/SlotManagerTests.swift`
- UI in: `PomodoroApp/Views/SlotTemplatesView.swift` or `PomodoroApp/Views/MenuBarView.swift`

**New Setting:**
- Property in: `PomodoroApp/Models/Settings.swift` (add @AppStorage)
- Tests in: `PomodoroAppTests/SettingsTests.swift`
- UI in: `PomodoroApp/Views/SettingsView.swift` (add control)
- Usage in: `PomodoroApp/ViewModels/PomodoroViewModel.swift` (if affecting timer behavior)

**New Statistic/Tracking:**
- Model in: `PomodoroApp/Models/Statistics.swift` (update DailyStats struct)
- Recording in: `PomodoroApp/ViewModels/PomodoroViewModel.swift` (call statistics.record*() method)
- Tests in: `PomodoroAppTests/StatisticsTests.swift`
- Display in: `PomodoroApp/Views/StatsView.swift`

**New View/Tab:**
- File: `PomodoroApp/Views/{Feature}View.swift`
- Add case to: `PomodoroApp/Views/MenuBarView.swift` (Tab enum, lines 16-21)
- Add switch branch in: `PomodoroApp/Views/MenuBarView.swift` (switch selectedTab, lines 40-49)
- Add picker button in: `PomodoroApp/Views/MenuBarView.swift` (Picker, lines 25-30)

**Helper/Utility View:**
- File: `PomodoroApp/Views/{Component}View.swift`
- Used in: Target view that needs the component

**macOS Integration Feature (menus, popover, notifications):**
- Code in: `PomodoroApp/PomodoroApp.swift` (AppDelegate class)
- Tests in: `PomodoroAppTests/` (if testable; AppDelegate UI integration is typically manual)

## Special Directories

**Resources/Assets.xcassets/**
- Purpose: Store app icons and image assets
- Generated: Partially (Xcode manages structure)
- Committed: Yes

**Resources/SourceAssets/**
- Purpose: Source design files (e.g., Figma exports, SVG sources)
- Generated: No
- Committed: Yes

**.planning/codebase/**
- Purpose: GSD analysis artifacts (ARCHITECTURE.md, STRUCTURE.md, etc.)
- Generated: Yes (by GSD mapper)
- Committed: Yes

**PomodoroApp.xcodeproj/**
- Purpose: Xcode project configuration, build settings, scheme definitions
- Generated: Partially (Xcode manages; some files auto-generated)
- Committed: Yes

---

*Structure analysis: 2026-02-12*
