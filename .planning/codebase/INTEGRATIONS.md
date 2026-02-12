# External Integrations

**Analysis Date:** 2026-02-12

## APIs & External Services

**Not Applicable:**
- No remote APIs consumed
- No cloud service integrations
- No third-party authentication providers
- No analytics or telemetry

## Data Storage

**Databases:**
- None - This is a single-user local application

**File Storage:**
- Local filesystem only (macOS UserDefaults and Application Support)
- Settings: Stored in `~/Library/Preferences/com.apple.dt.Xcode.plist` via @AppStorage
- Statistics/Sessions: Stored in `~/Library/Application Support/` as JSON via Codable

**Caching:**
- None - All data is immediately persisted

**Persistence Details:**
- Settings cache key: `@AppStorage` properties in `Settings.swift`
  - `workDuration`, `shortBreakDuration`, `longBreakDuration`, `pomodorosBeforeLongBreak`
  - `autoStartBreaks`, `autoStartWork`, `playSound`, `completionSoundName`, `showNotifications`, `showSlotNameInMenuBar`
- Statistics cache: UserDefaults key `pomodoroStatistics` (DailyStats array)
- Sessions cache: UserDefaults key `pomodoroSessions` (TimerSession array, limited to 1000 most recent)

## Authentication & Identity

**Not Applicable:**
- No user authentication
- No account system
- No login required

## Notifications & Alerts

**Desktop Notifications:**
- UserNotifications framework via `UNUserNotificationCenter`
- Implementation: `PomodoroViewModel.sendNotification(for:)` (line 220-248)
- Uses: `UNMutableNotificationContent`, `UNNotificationRequest`
- Behavior: Shows macOS notification center alerts when timer states complete
- Permission: Requested on app launch via `requestNotificationPermission()` (line 216-218)

**System Sounds:**
- macOS system sounds played via NSSound
- Available sounds: Glass, Ping, Pop, Purr, Sosumi, Submarine, Hero, Blow, Bottle, Frog, Funk, Morse, Tink
- Implementation: `PomodoroViewModel.playCompletionSound()` (line 251-258)
- Uses: `NSSound(named:)` with user-selected completion sound
- Fallback: `NSSound.beep()` if sound file not found

## Monitoring & Observability

**Error Tracking:**
- None

**Logs:**
- Console output from build scripts (build.sh, test.sh)
- No application logging framework

**Debugging:**
- Native Xcode debugging
- Print statements in test files only

## CI/CD & Deployment

**Hosting:**
- GitHub releases only (no automatic deployment)

**CI Pipeline:**
- None configured - Manual builds and testing

**Build Scripts:**
- `Scripts/build.sh` - Builds Release configuration, uses xcpretty if available
- `Scripts/test.sh` - Runs XCTest suite
- `Scripts/export-app.sh` - Exports signed and notarized app

**Distribution:**
- GitHub releases: Manual upload of built .app bundle
- No code signing certificate required for local builds
- Warning displayed on first run for unsigned distribution

## Environment Configuration

**Required Environment Variables:**
- None - All configuration via in-app settings

**Required Credentials:**
- None - Fully self-contained

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

## Accessibility & Permissions

**System Permissions Requested:**
- Notification permissions: `[.alert, .sound]` (UserNotifications)
- Accessibility: None currently
- Microphone/Camera: None

**macOS Entitlements:**
- App Sandbox: Enabled
- Code signing requirement: No (unsigned builds work with warning)
- No special entitlements required for menubar app

## Data Privacy

**Data Collection:**
- None - No telemetry or data collection

**Local Data Only:**
- All user data (settings, statistics, sessions) stored locally
- No cloud sync
- No data export features

## System Audio Integration

**macOS Built-in Sounds:**
- Completion sounds sourced from: `/System/Library/Sounds/`
- Available via NSSound.Name: CompletionSound enum in `Settings.swift` (line 5-21)
- User-selectable via SettingsView
- Played immediately on timer completion or skip

---

*Integration audit: 2026-02-12*
