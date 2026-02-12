# Architecture

**Analysis Date:** 2026-02-12

## Pattern Overview

**Overall:** MVVM (Model-View-ViewModel) with stateful managers

**Key Characteristics:**
- Clear separation between Models (data/state), ViewModels (business logic), and Views (UI)
- @MainActor-annotated ViewModels for thread-safe UI updates
- ObservableObject pattern for reactive updates via Combine
- Menubar-only application (LSUIElement = true in Xcode config)
- AppDelegate handles native macOS UI integration (status item, popover, context menus)

## Layers

**Models (Data & Domain Logic):**
- Purpose: Define data structures, state machines, and persistence logic
- Location: `PomodoroApp/Models/`
- Contains: Enums (TimerState), structs (Slot, DailySlots, DailyStats, TimerSession), and managers (SlotManager, Statistics)
- Depends on: Foundation, UserDefaults for persistence
- Used by: ViewModels and Views for data binding

**ViewModels (Business Logic & State Management):**
- Purpose: Orchestrate model updates, handle timer logic, manage notifications and sounds
- Location: `PomodoroApp/ViewModels/`
- Contains: PomodoroViewModel (main coordinator), Settings (user preferences via AppStorage)
- Depends on: Models, Combine, UserNotifications, AppKit
- Used by: Views for reactive updates; AppDelegate for status bar updates

**Views (UI & Presentation):**
- Purpose: Display state and capture user interactions
- Location: `PomodoroApp/Views/`
- Contains: SwiftUI views organized by feature (MenuBarView, TimerView, SlotsView, StatsView, SettingsView, etc.)
- Depends on: ViewModels and Models
- Used by: MenuBarView coordinates all views; individual views are context-specific

**AppDelegate (macOS Integration):**
- Purpose: Bridge SwiftUI to native macOS APIs (menubar, popover, context menus, notifications)
- Location: `PomodoroApp/PomodoroApp.swift` (lines 26-337)
- Contains: Status item management, popover control, timer visual effects (blink, marquee), context menu
- Depends on: AppKit, PomodoroViewModel
- Used by: App entry point

## Data Flow

**Timer Operation Cycle:**

1. User clicks "Play" or calls `PomodoroViewModel.startWork()`
2. ViewModel sets state to `.work`, initializes `timeRemaining`, starts Timer
3. Timer ticks every 1 second, calls `tick()` which decrements `timeRemaining`
4. @Published properties update, triggering view re-renders and AppDelegate status button updates
5. When `timeRemaining` reaches 0, `timerCompleted()` executes:
   - Records session in Statistics
   - Advances SlotManager completion count
   - Sends notification and plays sound
   - Transitions to next state (break or work)
6. AppDelegate continuously observes `@Published` properties and updates menubar display

**Slot Progression:**

1. SlotManager loads today's slots from UserDefaults or initializes from template
2. Timer completes a work session → SlotManager.advanceCompletion() increments completedCount
3. currentSlotName computed property returns `today.slots[today.completedCount]`
4. View displays current slot name in TimerView and menubar (if enabled)
5. New day detected → SlotManager.checkForNewDay() saves history, initializes fresh day

**State Management:**

- **Timer State:** Managed by PomodoroViewModel via @Published timerState (enum: idle/work/shortBreak/longBreak)
- **Running State:** Managed by Timer instance in ViewModel; @Published isRunning triggers UI updates
- **Settings:** Persisted via @AppStorage in Settings class; observable by ViewModel
- **Statistics:** Daily pomodoro counts and session records persist to UserDefaults
- **Slots:** Daily slot list and completion progress persists to UserDefaults; auto-creates new day entry

## Key Abstractions

**TimerState Enum:**
- Purpose: Represents the current phase of the Pomodoro cycle
- Examples: `PomodoroApp/Models/TimerState.swift`
- Pattern: Case enum with computed properties for display names, UI icons, and menubar icons
- Values: .idle (ready), .work (focus), .shortBreak (5 min rest), .longBreak (15 min rest)

**SlotManager:**
- Purpose: Manages daily task slots (the work breakdown) and history of completed days
- Examples: `PomodoroApp/Models/SlotManager.swift`
- Pattern: ObservableObject that coordinates DailySlots, slot edits, templates, placeholders, and persistence
- Core operations: addSlot, removeSlot, renameSlot, advanceCompletion, checkForNewDay, applyTemplate
- Persistence: Saves to UserDefaults under keys "pomodoroSlots", "pomodoroSlotsHistory_v2", "defaultSlotNames"

**Settings:**
- Purpose: User preference storage and computation (durations, auto-start, notifications, sounds)
- Examples: `PomodoroApp/Models/Settings.swift`
- Pattern: ObservableObject using @AppStorage for automatic persistence
- Provides: duration(for:) method that returns seconds based on timerState

**Statistics:**
- Purpose: Track completed pomodoros, focus minutes, and session history
- Examples: `PomodoroApp/Models/Statistics.swift`
- Pattern: ObservableObject that maintains dailyStats and sessions arrays
- Computed: todayStats, weeklyPomodoros, monthlyPomodoros, last7Days
- Persistence: Saves to UserDefaults under "pomodoroStatistics" and "pomodoroSessions"

**PomodoroViewModel:**
- Purpose: Coordinate timer logic, slot advancement, and notifications
- Examples: `PomodoroApp/ViewModels/PomodoroViewModel.swift`
- Pattern: @MainActor ObservableObject with Timer instance for 1-second tick loop
- Properties: @Published timerState, timeRemaining, isRunning; computed progress, menuBarTitle
- Methods: startWork(), pause(), resume(), skip(), completeEarly(), toggleTimer()
- Handles: Timer ticks, session recording, notifications, sound playback, state transitions

## Entry Points

**App Startup:**
- Location: `PomodoroApp/PomodoroApp.swift` (lines 5-24)
- Triggers: App launch (macOS AppKit activation)
- Responsibilities: Hides dock icon (LSUIElement), creates empty window, delegates to AppDelegate

**AppDelegate.applicationDidFinishLaunching:**
- Location: `PomodoroApp/PomodoroApp.swift` (lines 46-108)
- Triggers: After @main app initializes
- Responsibilities: Creates ViewModel, popover, status item, subscribes to notifications, checks for new day

**MenuBarView.onAppear:**
- Location: `PomodoroApp/Views/MenuBarView.swift` (lines 73-81)
- Triggers: Popover content loads
- Responsibilities: Checks for new day, prompts to fill template placeholders if needed

## Error Handling

**Strategy:** Defensive guard statements with safe fallbacks

**Patterns:**

- **Persistence failures:** JSON decode/encode wrapped in `try?`; if decode fails, initialize fresh state (e.g., SlotManager initializes new day if load fails)
- **Slot access:** `guard index >= 0 && index < array.count else { return }` before modifying
- **State transitions:** Guard that timerState is not .idle before operations like pause/resume
- **Notification permissions:** Requested silently in init without blocking UI; authorization callback ignored
- **Sound playback:** Fallback to NSSound.beep() if named sound not found in system library

## Cross-Cutting Concerns

**Logging:** Not implemented. Debugging via breakpoints and print statements in development.

**Validation:**
- Slot names: No validation; accepts any string including empty strings
- Durations: Duration values clamped via max(0, ...) in getters
- Placeholder syntax: Regex pattern `\[([^\]]+)\]` to extract bracketed placeholders

**Authentication:** Not applicable (local app, no network/user accounts).

**Serialization:**
- Models conform to Codable
- JSONEncoder/JSONDecoder via UserDefaults.data(forKey:)
- Date serialization: ISO format handled by default Codable date strategy

**Thread Safety:**
- @MainActor on PomodoroViewModel ensures all UI updates happen on main thread
- Timer.scheduledTimer runs on main thread by default
- Combine subscribers receive updates on main thread via .receive(on: RunLoop.main)

---

*Architecture analysis: 2026-02-12*
