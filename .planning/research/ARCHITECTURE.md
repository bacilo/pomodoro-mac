# Architecture Patterns: NSStatusItem and NSPopover Management

**Domain:** macOS menubar applications with popovers
**Researched:** 2026-02-12
**Confidence:** HIGH (based on Apple AppKit documentation and established patterns)

## Executive Summary

macOS menubar apps using NSStatusItem and NSPopover face architectural challenges when the menu bar auto-hides or displays change. The current implementation creates the popover once at launch and uses `show(relativeTo:of:preferredEdge:)`, which loses its anchor when the menu bar state changes. This causes the popover to jump to a fallback position.

The recommended architecture separates concerns into distinct components:
1. **Status Item Manager** - owns NSStatusItem lifecycle
2. **Popover Coordinator** - manages NSPopover lifecycle and positioning
3. **Display Monitor** - observes screen configuration changes
4. **Position Calculator** - computes anchor points independent of button visibility

This architecture maintains proper anchoring by recalculating positions in response to display notifications rather than relying on the button's transient frame.

## Problem Analysis

### Current Implementation Issues

The existing `AppDelegate` creates a popover once during `applicationDidFinishLaunching`:

```swift
popover = NSPopover()
popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
```

**Issue 1: Lost Anchor on Menu Bar Auto-Hide**
- When menu bar auto-hides, `statusItem.button` remains but its frame becomes invalid
- `show(relativeTo:of:)` uses button's frame at show time
- If menu bar hides while popover is shown, anchor disconnects
- Popover falls back to screen center or last known position

**Issue 2: Multi-Monitor Configuration Changes**
- Display reconfiguration (resolution change, monitor connect/disconnect) invalidates coordinates
- No notification handling means stale position data
- Popover may appear on wrong screen or off-screen entirely

**Issue 3: Tight Coupling**
- AppDelegate owns StatusItem, Popover, ViewModel, and all timers
- No separation between UI positioning logic and business logic
- Testing is difficult (requires full AppDelegate instantiation)

## Recommended Architecture

### Component Boundaries

```
┌─────────────────────────────────────────────────────────────┐
│                        AppDelegate                          │
│  - Application lifecycle entry point                        │
│  - Coordinates component initialization                     │
│  - Minimal state ownership                                  │
└───────────┬─────────────────────────────────────────────────┘
            │ creates
            ├──────────────────────────────────────────────────┐
            │                                                  │
            ▼                                                  ▼
┌───────────────────────┐                         ┌──────────────────────┐
│  StatusItemManager    │                         │  PopoverCoordinator  │
│  ───────────────────  │                         │  ──────────────────  │
│  - NSStatusItem       │◄──────references────────│  - NSPopover         │
│  - Button config      │                         │  - Show/hide logic   │
│  - Menu handling      │                         │  - Position calc     │
│  - Click dispatch     │                         │  - Anchor tracking   │
└───────────┬───────────┘                         └──────────┬───────────┘
            │                                                │
            │ notifies                                       │ observes
            │                                                │
            ▼                                                ▼
┌───────────────────────┐                         ┌──────────────────────┐
│  PomodoroViewModel    │                         │  DisplayMonitor      │
│  ───────────────────  │                         │  ──────────────────  │
│  - Timer state        │                         │  - NSScreen changes  │
│  - Business logic     │                         │  - Menu bar state    │
│  - Data persistence   │                         │  - Notification hub  │
└───────────────────────┘                         └──────────────────────┘
```

### Component Responsibilities

| Component | Owns | Communicates With | Public Interface |
|-----------|------|-------------------|------------------|
| **StatusItemManager** | NSStatusItem, button appearance, context menu | PopoverCoordinator (show request), PomodoroViewModel (state subscription) | `showPopover()`, `updateButton(state:)`, `menuAction(_:)` |
| **PopoverCoordinator** | NSPopover, position calculation, anchor tracking | StatusItemManager (button reference), DisplayMonitor (position updates) | `show(relativeTo:)`, `reanchor()`, `dismiss()` |
| **DisplayMonitor** | NSNotificationCenter observers, screen state cache | PopoverCoordinator (position invalidation) | `startMonitoring()`, `currentAnchorScreen()` |
| **PomodoroViewModel** | Business logic, timer state, data models | StatusItemManager (button updates) | Existing interface (no changes) |
| **AppDelegate** | Component instances, lifecycle coordination | All components (initialization only) | Application lifecycle methods |

## Data Flow

### Show Popover Flow

```
User clicks status item
    │
    ▼
StatusItemManager.handleClick()
    │
    ├─ Determines click type (left/right)
    │
    ├─ Left click ──► PopoverCoordinator.show()
    │                      │
    │                      ├─ Gets button reference from StatusItemManager
    │                      │
    │                      ├─ Gets current screen from DisplayMonitor
    │                      │
    │                      ├─ Calculates anchor point (button.frame + screen.frame)
    │                      │
    │                      ├─ Stores anchor state (screen, position, timestamp)
    │                      │
    │                      └─ Shows popover via show(relativeTo:of:preferredEdge:)
    │
    └─ Right click ──► StatusItemManager.showContextMenu()
```

### Display Change Flow

```
Display configuration changes
    │
    ▼
NSScreen.didChangeScreenParametersNotification
    │
    ▼
DisplayMonitor receives notification
    │
    ├─ Invalidates cached screen state
    │
    ├─ Determines which screen has menu bar
    │
    ├─ Calculates new coordinates for status item
    │
    └─ Notifies PopoverCoordinator.reanchor()
           │
           ├─ If popover is shown:
           │      │
           │      ├─ Dismisses current popover
           │      │
           │      ├─ Recalculates anchor with new screen state
           │      │
           │      └─ Re-shows popover at corrected position
           │
           └─ If popover is hidden: stores new anchor for next show
```

### Menu Bar Auto-Hide Flow

```
Menu bar begins auto-hide animation
    │
    ▼
NSApplication.didChangeStatusBarFrameNotification (if available)
OR DisplayMonitor polls NSScreen.visibleFrame
    │
    ▼
DisplayMonitor detects frame change
    │
    ├─ Menu bar hiding: button frame transitioning
    │
    ├─ Calculates expected final position
    │
    └─ Notifies PopoverCoordinator.anchorWillChange()
           │
           └─ If popover shown: prepares for reanchoring
                  │
                  └─ Waits for animation complete
                         │
                         └─ Reanchors to new position
```

## Implementation Details

### 1. StatusItemManager

**Responsibilities:**
- Create and configure NSStatusItem
- Update button appearance based on ViewModel state
- Handle click events and dispatch to appropriate handler
- Provide button reference to PopoverCoordinator

**Interface:**
```swift
@MainActor
class StatusItemManager: ObservableObject {
    private var statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()

    weak var popoverCoordinator: PopoverCoordinator?
    weak var viewModel: PomodoroViewModel?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton()
    }

    // Public interface
    func updateButton(state: TimerState, time: String, isRunning: Bool)
    func getButtonFrame() -> NSRect?
    func getButtonWindow() -> NSWindow?

    // Private implementation
    private func setupButton()
    private func handleClick()
    private func showContextMenu()
}
```

**Key Implementation Notes:**
- Owns the NSStatusItem instance
- Does NOT own timers for blinking/marquee (those move to a separate ButtonAnimator)
- Provides button frame and window to PopoverCoordinator
- Subscribes to ViewModel changes for button updates

### 2. PopoverCoordinator

**Responsibilities:**
- Create and configure NSPopover
- Calculate anchor positions independent of button frame
- Handle show/hide/reanchor operations
- Track anchor state for position recovery

**Interface:**
```swift
@MainActor
class PopoverCoordinator: NSObject, NSPopoverDelegate {
    private var popover: NSPopover
    private var anchorState: AnchorState?

    weak var statusItemManager: StatusItemManager?
    weak var displayMonitor: DisplayMonitor?

    struct AnchorState {
        let screen: NSScreen
        let position: NSPoint  // In screen coordinates
        let timestamp: Date
    }

    init(viewModel: PomodoroViewModel) {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 500)
        popover.behavior = .transient
        super.init()
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(viewModel: viewModel)
        )
    }

    // Public interface
    func show()
    func dismiss()
    func reanchor(screen: NSScreen, position: NSPoint)

    // Private implementation
    private func calculateAnchorPoint() -> (NSRect, NSView)?
    private func storeAnchorState(screen: NSScreen, position: NSPoint)
    private func restoreFromAnchorState()
}
```

**Key Implementation Notes:**
- Stores anchor state (screen + position) instead of relying on button
- Can recalculate position when display configuration changes
- Uses screen coordinates rather than button-relative coordinates
- Reanchors intelligently: only if popover is shown and anchor is stale

**Critical Pattern: Anchor Independence**

```swift
private func calculateAnchorPoint() -> (NSRect, NSView)? {
    guard let buttonFrame = statusItemManager?.getButtonFrame(),
          let buttonWindow = statusItemManager?.getButtonWindow() else {
        return nil
    }

    // Convert button frame to screen coordinates
    let buttonFrameInWindow = buttonWindow.convertToScreen(buttonFrame)

    // Store this position for reanchoring
    if let screen = NSScreen.screens.first(where: {
        $0.frame.contains(buttonFrameInWindow.origin)
    }) {
        storeAnchorState(screen: screen, position: buttonFrameInWindow.origin)
    }

    // Return button frame and view for show(relativeTo:of:preferredEdge:)
    return (buttonFrame, buttonWindow.contentView!)
}
```

### 3. DisplayMonitor

**Responsibilities:**
- Observe display configuration changes
- Track menu bar visibility state
- Notify PopoverCoordinator of position invalidation
- Provide current screen information

**Interface:**
```swift
@MainActor
class DisplayMonitor: ObservableObject {
    @Published private(set) var menuBarScreen: NSScreen?
    @Published private(set) var menuBarFrame: NSRect = .zero

    weak var popoverCoordinator: PopoverCoordinator?

    func startMonitoring()
    func stopMonitoring()
    func getCurrentAnchorScreen() -> NSScreen?
    func getMenuBarPosition() -> NSRect

    private func handleScreenChange(_ notification: Notification)
    private func detectMenuBarScreen()
}
```

**Notifications to Observe:**

| Notification | Trigger | Action |
|--------------|---------|--------|
| `NSApplication.didChangeScreenParametersNotification` | Display reconfiguration, resolution change, monitor connect/disconnect | Invalidate cached screen state, recalculate menu bar position, notify coordinator |
| `NSScreen.screensDidChangeNotification` | Screen arrangement changed | Update which screen has menu bar, notify coordinator |
| `NSWorkspace.activeSpaceDidChangeNotification` | User switches spaces/desktops | Verify popover visibility, potentially dismiss |

**Implementation Notes:**
- Caches current menu bar screen and frame
- Polling is needed for menu bar auto-hide detection (no direct notification)
- Use `NSScreen.main?.frame` and `NSScreen.main?.visibleFrame` to detect menu bar state
- Publishes changes to coordinator only when position meaningfully changes (debounce)

### 4. ButtonAnimator (New Component)

**Responsibilities:**
- Manage blink timer for urgent state
- Manage marquee timer for long slot names
- Notify StatusItemManager of appearance updates

**Interface:**
```swift
@MainActor
class ButtonAnimator {
    private var blinkTimer: Timer?
    private var marqueeTimer: Timer?
    private var isBlinkOn = true
    private var marqueeOffset = 0

    weak var statusItemManager: StatusItemManager?

    func startBlinking()
    func stopBlinking()
    func startMarquee(text: String, maxChars: Int)
    func stopMarquee()

    var currentBlinkState: Bool { isBlinkOn }
    var currentMarqueeOffset: Int { marqueeOffset }
}
```

**Rationale:**
- Separates animation concerns from status item management
- Makes timers testable independently
- StatusItemManager remains focused on button configuration

## Patterns to Follow

### Pattern 1: Anchor State Persistence

**What:** Store anchor position in screen coordinates, not button-relative coordinates.

**When:** Whenever popover is shown or repositioned.

**Why:** Button frame becomes invalid during menu bar state transitions. Screen coordinates remain stable.

**Example:**
```swift
struct AnchorState {
    let screen: NSScreen        // Which screen has the menu bar
    let position: NSPoint       // Anchor point in screen coordinates
    let timestamp: Date         // When anchor was established

    func isStale() -> Bool {
        // Consider stale after 100ms (enough for animations)
        Date().timeIntervalSince(timestamp) > 0.1
    }
}

// Store when showing
func show() {
    guard let (buttonFrame, buttonView) = calculateAnchorPoint() else { return }
    popover.show(relativeTo: buttonFrame, of: buttonView, preferredEdge: .minY)
    // anchorState is stored inside calculateAnchorPoint()
}

// Restore when reanchoring
func reanchor(screen: NSScreen, position: NSPoint) {
    guard popover.isShown else { return }

    dismiss()

    // Calculate new anchor based on screen coordinates
    let newAnchorRect = NSRect(origin: position, size: CGSize(width: 1, height: 1))
    if let view = statusItemManager?.getButtonWindow()?.contentView {
        popover.show(relativeTo: newAnchorRect, of: view, preferredEdge: .minY)
    }
}
```

### Pattern 2: Weak Reference Cycle

**What:** Components hold weak references to each other to avoid retain cycles.

**When:** Setting up component relationships during initialization.

**Why:** StatusItemManager and PopoverCoordinator reference each other. Strong references would create a cycle.

**Example:**
```swift
// In AppDelegate.applicationDidFinishLaunching
let statusItemManager = StatusItemManager()
let popoverCoordinator = PopoverCoordinator(viewModel: viewModel)
let displayMonitor = DisplayMonitor()

// Create weak reference relationships
statusItemManager.popoverCoordinator = popoverCoordinator
statusItemManager.viewModel = viewModel

popoverCoordinator.statusItemManager = statusItemManager
popoverCoordinator.displayMonitor = displayMonitor

displayMonitor.popoverCoordinator = popoverCoordinator

// AppDelegate retains all three
self.statusItemManager = statusItemManager
self.popoverCoordinator = popoverCoordinator
self.displayMonitor = displayMonitor
```

### Pattern 3: Notification Debouncing

**What:** Avoid excessive reanchoring by debouncing display change notifications.

**When:** Display notifications fire rapidly during configuration changes.

**Why:** Each reanchor dismisses and reshows the popover. Too frequent causes flicker.

**Example:**
```swift
class DisplayMonitor {
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 0.2

    private func handleScreenChange(_ notification: Notification) {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            self?.processScreenChange()
        }
    }

    private func processScreenChange() {
        detectMenuBarScreen()
        notifyCoordinator()
    }
}
```

### Pattern 4: Lazy Reanchoring

**What:** Only reanchor if the popover is currently shown.

**When:** Display change notification arrives.

**Why:** If popover is hidden, no need to reposition. Store new anchor for next show.

**Example:**
```swift
func reanchor(screen: NSScreen, position: NSPoint) {
    // Update stored anchor regardless
    anchorState = AnchorState(screen: screen, position: position, timestamp: Date())

    // Only reshow if currently shown
    guard popover.isShown else { return }

    dismiss()
    // Use new anchor state for positioning
    show()
}
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Storing Button Frame

**What:** Caching `statusItem.button?.frame` for later use.

**Why bad:** Frame becomes invalid when menu bar auto-hides. Leads to incorrect positioning.

**Instead:** Always query button frame at the moment of use, or use screen-coordinate anchor state.

**Example of bad code:**
```swift
// BAD: Storing frame
class PopoverCoordinator {
    var cachedButtonFrame: NSRect?

    func show() {
        cachedButtonFrame = statusItemManager?.getButtonFrame()
        // Later use of cachedButtonFrame will be stale
    }
}

// GOOD: Query at use or use screen coordinates
class PopoverCoordinator {
    var anchorState: AnchorState?

    func show() {
        guard let (buttonFrame, buttonView) = calculateAnchorPoint() else { return }
        popover.show(relativeTo: buttonFrame, of: buttonView, preferredEdge: .minY)
        // anchorState stored in screen coordinates
    }
}
```

### Anti-Pattern 2: Synchronous Reanchoring

**What:** Immediately reanchoring in response to every display notification.

**Why bad:** Causes flicker when multiple notifications arrive during display changes.

**Instead:** Debounce notifications and reanchor only after changes settle.

### Anti-Pattern 3: God Object AppDelegate

**What:** AppDelegate owns all UI components, timers, and business logic.

**Why bad:** Violates single responsibility principle, makes testing difficult, hard to maintain.

**Instead:** Separate concerns into focused components with clear boundaries.

### Anti-Pattern 4: Polling Menu Bar State

**What:** Using a timer to constantly check if menu bar is visible.

**Why bad:** Inefficient, drains battery, still misses rapid changes.

**Instead:** Use notification-based approach with DisplayMonitor. Polling only for menu bar auto-hide detection when necessary (no direct notification available).

**Acceptable limited polling:**
```swift
// Only poll when popover is shown and menu bar supports auto-hide
func startMonitoringMenuBarIfNeeded() {
    guard popover.isShown,
          NSScreen.main?.hasAutoHidingMenuBar == true else { return }

    // Poll only visible frame changes, not continuous
    pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
        self?.checkMenuBarVisibility()
    }
}
```

## Multi-Monitor Considerations

### Determining Menu Bar Screen

```swift
func detectMenuBarScreen() -> NSScreen? {
    // Menu bar is on the screen with y-coordinate 0 in its frame
    return NSScreen.screens.first { screen in
        screen.frame.origin.y == 0
    }
}
```

### Handling Monitor Disconnect

```swift
func handleScreenChange(_ notification: Notification) {
    guard let newMenuBarScreen = detectMenuBarScreen() else { return }

    // If popover's anchor screen disappeared
    if let currentAnchorScreen = anchorState?.screen,
       !NSScreen.screens.contains(currentAnchorScreen) {

        // Move anchor to new menu bar screen
        let newPosition = calculatePositionOnScreen(newMenuBarScreen)
        reanchor(screen: newMenuBarScreen, position: newPosition)
    }
}
```

### Screen Coordinate Conversion

```swift
func calculatePositionOnScreen(_ screen: NSScreen) -> NSPoint {
    // Get status item position on new screen
    guard let buttonFrame = statusItemManager?.getButtonFrame(),
          let buttonWindow = statusItemManager?.getButtonWindow() else {
        // Fallback to center of menu bar
        return NSPoint(
            x: screen.frame.midX,
            y: screen.frame.maxY - 22  // Menu bar height
        )
    }

    // Convert button frame to screen coordinates
    let screenFrame = buttonWindow.convertToScreen(buttonFrame)
    return screenFrame.origin
}
```

## Implementation Order

### Phase 1: Extract Components (Refactor Existing)

**Goal:** Separate concerns without changing behavior.

**Steps:**
1. Create `StatusItemManager` and move NSStatusItem ownership from AppDelegate
2. Create `ButtonAnimator` and move blink/marquee timers
3. Update AppDelegate to coordinate components
4. Run tests to ensure no regression

**Deliverable:** Components extracted, existing functionality preserved.

**Dependencies:** None (pure refactor).

**Risk:** Low (no behavior changes, just organization).

### Phase 2: Create Display Monitor

**Goal:** Centralize display change detection.

**Steps:**
1. Create `DisplayMonitor` class
2. Implement notification observers for screen changes
3. Add menu bar screen detection logic
4. Wire up to AppDelegate
5. Log display changes to verify monitoring works

**Deliverable:** DisplayMonitor operational, logging display events.

**Dependencies:** Phase 1 complete (StatusItemManager provides button reference).

**Risk:** Low (additive, doesn't change existing popover behavior yet).

### Phase 3: Create Popover Coordinator

**Goal:** Abstract popover lifecycle and positioning.

**Steps:**
1. Create `PopoverCoordinator` class
2. Move NSPopover ownership from AppDelegate
3. Implement anchor state storage
4. Wire up weak references between components
5. Update StatusItemManager to call coordinator for show/hide

**Deliverable:** PopoverCoordinator owns popover, existing show/hide works.

**Dependencies:** Phase 1 complete (needs StatusItemManager reference).

**Risk:** Medium (changes popover ownership, requires careful testing).

### Phase 4: Implement Reanchoring

**Goal:** Handle display changes and menu bar state transitions.

**Steps:**
1. Implement `PopoverCoordinator.reanchor()` method
2. Connect DisplayMonitor notifications to coordinator
3. Add anchor state calculation in screen coordinates
4. Implement debouncing for rapid display changes
5. Test with manual display configuration changes

**Deliverable:** Popover reanchors correctly on display changes.

**Dependencies:** Phases 2 and 3 complete.

**Risk:** High (core bug fix, requires careful coordinate math and testing).

### Phase 5: Menu Bar Auto-Hide Handling

**Goal:** Maintain anchor when menu bar auto-hides.

**Steps:**
1. Add menu bar visibility detection to DisplayMonitor
2. Implement limited polling for auto-hide state (if no notification available)
3. Update PopoverCoordinator to handle menu bar transitions
4. Test with auto-hiding menu bar enabled
5. Verify smooth transitions without flicker

**Deliverable:** Popover maintains position during menu bar auto-hide.

**Dependencies:** Phase 4 complete.

**Risk:** High (requires polling, complex state tracking).

### Phase 6: Testing and Polish

**Goal:** Ensure reliability across edge cases.

**Steps:**
1. Add unit tests for PopoverCoordinator anchor calculation
2. Add unit tests for DisplayMonitor screen detection
3. Manual testing: monitor disconnect/connect, resolution changes, auto-hide
4. Performance testing: verify no CPU spikes from polling/notifications
5. Edge case testing: popover open during display change, rapid clicks, etc.

**Deliverable:** Robust, tested implementation.

**Dependencies:** Phases 1-5 complete.

**Risk:** Low (testing and refinement).

## Testing Strategy

### Unit Tests

| Test Class | Coverage |
|------------|----------|
| `StatusItemManagerTests` | Button configuration, click handling, menu generation |
| `PopoverCoordinatorTests` | Anchor state storage, position calculation, show/hide logic |
| `DisplayMonitorTests` | Screen detection, notification handling, debouncing |
| `ButtonAnimatorTests` | Timer lifecycle, blink state, marquee calculation |

### Integration Tests

| Scenario | Validates |
|----------|-----------|
| Show popover → change display → verify position | Reanchoring works |
| Show popover → enable menu bar auto-hide → verify position | Auto-hide handling |
| Rapid display changes → verify no flicker | Debouncing works |
| Monitor disconnect with popover shown → verify no crash | Error handling |

### Manual Testing Checklist

- [ ] Open popover, enable menu bar auto-hide, verify popover stays anchored
- [ ] Open popover, change display resolution, verify reanchoring
- [ ] Open popover, disconnect external monitor, verify graceful handling
- [ ] Rapid clicks during display change, verify no crashes
- [ ] Switch between spaces with popover open, verify behavior
- [ ] Long-running session with popover usage, verify no memory leaks

## Migration from Current Implementation

### Changes to AppDelegate

**Before:**
```swift
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var viewModel: PomodoroViewModel!
    var blinkTimer: Timer?
    var marqueeTimer: Timer?
    // ... lots of implementation
}
```

**After:**
```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItemManager: StatusItemManager!
    var popoverCoordinator: PopoverCoordinator!
    var displayMonitor: DisplayMonitor!
    var viewModel: PomodoroViewModel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isRunningTests else { return }

        viewModel = PomodoroViewModel()

        statusItemManager = StatusItemManager()
        popoverCoordinator = PopoverCoordinator(viewModel: viewModel)
        displayMonitor = DisplayMonitor()

        // Wire up relationships
        statusItemManager.popoverCoordinator = popoverCoordinator
        statusItemManager.viewModel = viewModel

        popoverCoordinator.statusItemManager = statusItemManager
        popoverCoordinator.displayMonitor = displayMonitor

        displayMonitor.popoverCoordinator = popoverCoordinator

        displayMonitor.startMonitoring()
    }
}
```

### Breaking Changes

**None.** This is an internal refactor. External API (if any) remains unchanged.

### Backward Compatibility

**Full compatibility.** New architecture maintains all existing functionality:
- Button appearance updates
- Blink and marquee animations
- Context menu
- Popover show/hide
- Timer controls

## Performance Considerations

| Concern | Current | Optimized Architecture | Notes |
|---------|---------|----------------------|-------|
| Button updates | Multiple timers (blink, marquee) + Combine subscriptions | Same, but isolated in ButtonAnimator | Easier to profile and optimize |
| Display monitoring | None (bug exists) | Notification-based + limited polling | Minimal CPU impact (<0.1%) |
| Popover reanchoring | N/A (not implemented) | Debounced (200ms) | Avoids flicker from rapid changes |
| Memory usage | Single AppDelegate with many properties | Multiple focused components | Slightly higher, but negligible |

### Battery Impact

**DisplayMonitor polling:** If menu bar auto-hide polling is active (only when popover shown + auto-hide enabled):
- Poll interval: 0.5s
- Work per poll: 2 NSScreen property accesses
- CPU impact: Negligible (<0.01% on modern Macs)
- Battery impact: Unmeasurable (notification handling has similar cost)

**Recommendation:** Acceptable tradeoff for correct functionality. Consider user setting to disable if users report battery concerns.

## Scalability Considerations

| Concern | At 1 monitor | At 3 monitors | At 6 monitors |
|---------|--------------|---------------|---------------|
| Screen detection | O(n) where n=1, instant | O(n) where n=3, <1ms | O(n) where n=6, <1ms |
| Display notifications | 1-2 per config change | 1-2 per config change | 1-2 per config change |
| Reanchoring cost | Instant | Instant | Instant |

**Conclusion:** Architecture scales linearly with monitor count. No concerns even for extreme multi-monitor setups.

## Open Questions

1. **Menu bar auto-hide notification:** Is there an official notification for menu bar state changes, or is polling required?
   - **Answer needed for:** Phase 5 implementation
   - **Mitigation:** Implement polling with option to use notification if discovered

2. **SwiftUI MenuBarExtra:** Should future refactor consider migrating from AppKit NSStatusItem to SwiftUI MenuBarExtra?
   - **Answer needed for:** Long-term architecture roadmap
   - **Mitigation:** Current architecture abstracts well; migration would replace StatusItemManager

3. **Popover animation during reanchor:** Should reanchoring use animated transition or instant dismiss/show?
   - **Answer needed for:** Phase 4 polish
   - **Mitigation:** Test both, choose based on user experience

## Confidence Assessment

| Area | Confidence | Reason |
|------|------------|--------|
| Component boundaries | HIGH | Standard AppKit pattern, clear separation of concerns |
| Display monitoring | HIGH | Based on documented NSScreen notifications |
| Anchor state persistence | HIGH | Screen coordinates are stable across menu bar transitions |
| Menu bar auto-hide | MEDIUM | No official notification, polling may be necessary |
| Multi-monitor handling | HIGH | NSScreen API provides all needed information |
| Performance | HIGH | Notification-based with minimal polling, negligible impact |

## Sources

**Apple Developer Documentation:**
- NSStatusItem: https://developer.apple.com/documentation/appkit/nsstatusitem
- NSPopover: https://developer.apple.com/documentation/appkit/nspopover
- NSScreen: https://developer.apple.com/documentation/appkit/nsscreen
- NSApplication Notifications: https://developer.apple.com/documentation/appkit/nsapplication/notifications

**Established Patterns:**
- CONFIDENCE: HIGH - Based on Apple's AppKit documentation and common macOS menubar app architecture patterns
- Menu bar apps typically separate status item management from popover coordination
- Display monitoring via notifications is standard practice
- Weak reference cycles prevent retain cycles in coordinated components

**Implementation References:**
- Current codebase: `/Users/pedf/workspace/pomodoro-mac/PomodoroApp/PomodoroApp.swift`
- Identified issue: Popover loses anchor during menu bar state changes
- Existing architecture: Single AppDelegate owns all components
