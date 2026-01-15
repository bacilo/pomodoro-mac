# Architecture Overview

## Design Pattern: MVVM

This app follows the Model-View-ViewModel (MVVM) pattern with SwiftUI.

```
┌─────────────────────────────────────────────────────────┐
│                      Views (SwiftUI)                     │
│  MenuBarView → TimerView, SettingsView, StatsView       │
└─────────────────────┬───────────────────────────────────┘
                      │ @ObservedObject
┌─────────────────────▼───────────────────────────────────┐
│                   PomodoroViewModel                      │
│  - Timer logic and state management                      │
│  - Coordinates Settings and Statistics                   │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                      Models                              │
│  TimerState, Settings, Statistics, TimerSession         │
└─────────────────────────────────────────────────────────┘
```

## Key Components

### PomodoroApp.swift
Entry point using `@main`. Sets up `MenuBarExtra` for menubar-only app.

### Models

| Model | Purpose |
|-------|---------|
| `TimerState` | Enum for idle/work/shortBreak/longBreak states |
| `TimerSession` | Records individual timer sessions |
| `Settings` | User preferences with `@AppStorage` persistence |
| `Statistics` | Tracks and persists completed pomodoros |

### ViewModel

`PomodoroViewModel` is the central coordinator:
- Owns `Timer` instance for countdown
- Manages state transitions (work → break → work)
- Triggers notifications via `UNUserNotificationCenter`
- Records sessions to `Statistics`

### Views

| View | Purpose |
|------|---------|
| `MenuBarView` | Container with tab picker |
| `TimerView` | Circular progress, start/pause/reset controls |
| `SettingsView` | Duration steppers, automation toggles |
| `StatsView` | Daily/weekly/monthly counts, bar chart |

## Data Flow

1. User clicks menubar icon → `MenuBarView` popover opens
2. User taps Start → `PomodoroViewModel.startWork()` called
3. ViewModel starts `Timer`, updates `@Published` properties
4. SwiftUI re-renders `TimerView` with new countdown
5. Timer completes → ViewModel records to `Statistics`, sends notification
6. ViewModel transitions to next state (break/work)

## Persistence

- **Settings**: `@AppStorage` (UserDefaults) - immediate persistence
- **Statistics**: JSON in UserDefaults - saved after each completed session
- **Sessions**: Limited to last 1000 entries to prevent unbounded growth

## Threading

- `PomodoroViewModel` is `@MainActor` - all UI updates on main thread
- `Timer` callbacks dispatch to `@MainActor` via `Task`
