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

### Standard Installation

1. **Download** the `PomodoroApp-v*.zip` file from the latest release
2. **Extract** the .zip file (double-click in Finder)
3. **Move** the `PomodoroApp.app` to your `/Applications` folder
4. **First Launch**: Right-click → Open (required for unsigned apps on first launch)

> **macOS 15.1+ Sequoia users:** If you see a "damaged app" error or right-click → Open doesn't work, see the Sequoia Installation section below.

### macOS 15.1+ Sequoia Installation

macOS Sequoia has stricter security requirements for unsigned apps. Follow these steps:

1. Extract and move the app to `/Applications` as described above
2. Open Terminal (Applications → Utilities → Terminal)
3. Run this command to remove quarantine flags:
   ```bash
   xattr -cr /Applications/PomodoroApp.app
   ```
4. Go to **System Settings → Privacy & Security**
5. Scroll down and click **"Open Anyway"** next to PomodoroApp
6. Try launching the app again

**What does `xattr -cr` do?** This command removes security flags that macOS adds to downloaded apps. It does not modify the app code itself - it only removes the "quarantine" flag that blocks unsigned apps on Sequoia.

**Why is this needed?** macOS Sequoia 15.1+ removed the traditional right-click → Open bypass for unsigned apps. This command restores the ability to run the app after you explicitly approve it in System Settings.

### Verify Download (Optional)

To verify your download hasn't been corrupted:

1. Download `checksums.txt` from the release
2. Open Terminal and navigate to your Downloads folder:
   ```bash
   cd ~/Downloads
   ```
3. Run the verification command:
   ```bash
   shasum -a 256 -c checksums.txt
   ```
4. You should see: `PomodoroApp-v1.1.0.zip: OK`

### Build from Source

If you prefer to build from source instead:

```bash
# Clone the repository
git clone https://github.com/bacilo/pomodoro-mac.git
cd pomodoro-mac

# Build
xcodebuild build -project PomodoroApp.xcodeproj -scheme PomodoroApp -destination 'platform=macOS'

# Or open in Xcode
open PomodoroApp.xcodeproj
```

### Why isn't this app signed?

This is a free, open-source project without an Apple Developer account ($99/year required for code signing). The app uses ad-hoc signing for Apple Silicon compatibility, but isn't notarized by Apple. This is common for open-source macOS apps distributed outside the Mac App Store.

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
