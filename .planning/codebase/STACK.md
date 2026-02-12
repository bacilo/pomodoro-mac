# Technology Stack

**Analysis Date:** 2026-02-12

## Languages

**Primary:**
- Swift 5.9+ - All application and test code

**Secondary:**
- Bash - Build and test automation scripts

## Runtime

**Environment:**
- macOS 13.0+ (Ventura and later)
- Intel and Apple Silicon support

**Target Platform:**
- macOS application (menubar-only)
- No iOS, tvOS, or watchOS targets

## Frameworks

**Core UI:**
- SwiftUI - User interface framework
- AppKit - macOS native integration (NSStatusItem, NSPopover, NSApplication, NSSound)

**Reactive:**
- Combine - Reactive programming with @Published and AnyCancellable

**System Integration:**
- UserNotifications - Desktop notifications for timer completion

**Testing:**
- XCTest - Built-in testing framework (no external test libraries)

**Build/Dev:**
- Xcode 14.1+ (implied by Swift 5.9+)
- xcodebuild - Command-line build tool

## Key Dependencies

**No External Dependencies:**
- Project uses only Apple-provided frameworks
- No third-party package dependencies (CocoaPods, SPM, or Carthage)
- No external SDKs or integrations

**Built-in System Frameworks Used:**
- Foundation - Core types, DateFormatter, UserDefaults, Codable
- Combine - Reactive state management (@Published, ObservableObject)
- AppKit - Menubar integration (NSStatusBar, NSStatusItem, NSPopover, NSSound, NSApplication, NSApplicationDelegate)
- UserNotifications - Desktop alerts (UNUserNotificationCenter, UNMutableNotificationContent)
- SwiftUI - UI components and reactive views

## Configuration

**Build Configuration:**
- Project file: `PomodoroApp.xcodeproj/project.pbxproj`
- Schemes: PomodoroApp (main), PomodoroAppTests
- Build settings: Release and Debug configurations
- Deployment target: macOS 13.0

**App Configuration:**
- Info.plist: `PomodoroApp/Info.plist` - Contains LSUIElement = true (menubar-only mode)
- Entitlements: `PomodoroApp/PomodoroApp.entitlements` - App sandbox enabled

**User Preferences:**
- Stored via @AppStorage in UserDefaults
- No external configuration files required
- Settings persist across sessions: work duration, break durations, auto-start options, sound preferences, notification toggles

**Persistence:**
- UserDefaults for settings and app state
- JSON encoding/decoding (Codable) for statistics and session data
- Files stored in: ~/Library/Preferences/ (UserDefaults) and ~/Library/Application Support/ (app data)

## Platform Requirements

**Development:**
- Xcode 14.1 or later
- macOS 13.0 or later for building
- Command-line tools: xcodebuild, xcpretty (optional, for prettier output)

**Production:**
- Deployment target: macOS 13.0 (Ventura)
- Code signing: Unsigned (warning shown on first run)
- Sandboxed: Yes (app sandbox entitlement enabled)
- Menubar-only: Yes (LSUIElement = true, hidden from dock)

**Build Output:**
- Binary: `PomodoroApp.app` (macOS application bundle)
- Build location: Xcode build directory or provided export directory

---

*Stack analysis: 2026-02-12*
