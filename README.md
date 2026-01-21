# PomodoroApp

A macOS menubar Pomodoro timer app built with SwiftUI.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)

## Features

- **Menubar-only app** - Lives in your menubar, out of the way
- **Customizable durations** - Set your own work, short break, and long break times
- **Session tracking** - Track completed pomodoros with daily statistics
- **Sound notifications** - Audio alerts when timers complete
- **Keyboard shortcuts** - Quick controls without leaving your workflow

## Installation

### Download

Download the latest release from the [Releases](https://github.com/bacilo/pomodoro-mac/releases) page.

> **Note**: Since this app is not signed with an Apple Developer certificate, macOS will show a warning. To open it:
> 1. Right-click the app and select "Open"
> 2. Click "Open" in the dialog that appears

### Build from Source

```bash
# Clone the repository
git clone https://github.com/bacilo/pomodoro-mac.git
cd pomodoro-mac

# Build
xcodebuild build -project PomodoroApp.xcodeproj -scheme PomodoroApp -destination 'platform=macOS'

# Or open in Xcode
open PomodoroApp.xcodeproj
```

## Usage

1. Click the tomato icon in your menubar
2. Set your desired work duration
3. Click "Start" to begin a pomodoro session
4. Take breaks when prompted
5. Track your progress in the Stats view

## Development

See [CLAUDE.md](CLAUDE.md) for development guidelines, architecture overview, and contribution workflow.

```bash
# Run tests
xcodebuild test -project PomodoroApp.xcodeproj -scheme PomodoroApp -destination 'platform=macOS'
```

## License

MIT
