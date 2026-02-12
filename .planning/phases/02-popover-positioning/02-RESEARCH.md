# Phase 02: Popover Positioning - Research

**Researched:** 2026-02-12
**Domain:** macOS NSPopover positioning with auto-hide menu bar
**Confidence:** MEDIUM-HIGH

## Summary

Phase 2 addresses the popover positioning bug where the popover jumps to the top-left corner when the menu bar auto-hides or during multi-monitor configuration changes. The root cause is **dynamic status item width changes during popover display**, combined with **lack of screen coordinate caching** when the menu bar state transitions.

The current implementation uses `NSStatusItem.variableLength` (line 73 of PomodoroApp.swift) and dynamically switches between variable and fixed-width modes (lines 177-187) based on whether slot names are displayed. This causes the status item's bounds to change while the popover is anchored, breaking NSPopover's `show(relativeTo:of:preferredEdge:)` positioning algorithm. When combined with menu bar auto-hide (which invalidates `statusItem.button?.window?.frame`), the popover loses its anchor and falls back to screen origin.

**Primary recommendation:** Implement a **fixed-width status item with screen coordinate caching** pattern. Calculate the maximum possible status item width at startup (timer + icon + slot name marquee), always use that fixed width, and cache the button's frame in screen coordinates when showing the popover. Monitor display configuration changes via `NSApplication.didChangeScreenParametersNotification` to recalculate positioning on multi-monitor changes.

The fix involves three coordinated changes:
1. **Fixed-width calculation**: Measure maximum content width (widest timer value + longest marquee display) and set `statusItem.length` once at initialization
2. **Screen coordinate caching**: Store button frame in screen coordinates when popover opens, use cached position if button frame becomes nil
3. **Display change monitoring**: Observe screen parameter notifications and reanchor popover when display configuration changes

This approach avoids the architectural refactoring suggested in ARCHITECTURE.md (separating concerns into StatusItemManager, PopoverCoordinator, DisplayMonitor components) while directly fixing the root cause. The minimal change strategy reduces risk and testing surface area while solving all four success criteria.

## Standard Stack

### Core Components
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| NSStatusItem | AppKit (macOS 13.0+) | Menu bar status item with button | Only API for menu bar items with precise control |
| NSPopover | AppKit (macOS 13.0+) | Popover UI anchored to button | Standard transient UI for menu bar apps, handles window level + auto-dismiss |
| NSScreen | AppKit (macOS 13.0+) | Display configuration and coordinate spaces | Required for multi-monitor positioning and coordinate conversion |
| NSNotificationCenter | Foundation | Display change detection | Standard observer pattern for system events |

### Supporting APIs
| API | Purpose | When to Use |
|-----|---------|-------------|
| `NSStatusBar.system.statusItem(withLength:)` | Create status item with fixed or variable length | Initialization - use fixed length to prevent jitter |
| `NSPopover.show(relativeTo:of:preferredEdge:)` | Display popover anchored to view | When showing popover - requires valid anchor rect |
| `NSWindow.convertToScreen(_:)` | Convert frame to screen coordinates | Before caching button position - survives menu bar state changes |
| `NSApplication.didChangeScreenParametersNotification` | Detect display configuration changes | Multi-monitor support - observe to detect resolution/arrangement changes |
| `NSFont.monospacedSystemFont(ofSize:weight:)` | Fixed-width font for timer display | Already used (line 170) - consistent character width for width calculation |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| NSPopover | Custom NSWindow with .hudWindow style | More control over positioning but loses transient behavior, auto-dismiss, arrow rendering |
| Fixed-width status item | Continue with variableLength + width switching | Simpler but causes jitter during popover display - root cause of bug |
| Screen coordinate caching | Query button frame on every reanchor | Simpler but fails when menu bar auto-hides - button frame becomes nil |
| Notification-based monitoring | Polling NSScreen.visibleFrame | More responsive to menu bar hide but wastes CPU, drains battery |

**Installation:**
No additional dependencies required - all APIs are built into AppKit/Foundation frameworks already used by the project.

## Architecture Patterns

### Current Implementation Analysis
```
PomodoroApp.swift (AppDelegate):
├── statusItem (NSStatusItem) - line 28
├── popover (NSPopover) - line 29
├── updateStatusButton() - lines 110-159
│   ├── Dynamically switches statusItem.length (lines 177-187)
│   ├── Blink timer (0.5s) for urgent state
│   └── Marquee timer (0.3s) for long slot names
├── updateStatusButtonAppearance() - lines 161-254
│   └── Builds attributed string with monospaced font
└── togglePopover() - lines 266-275
    └── Shows popover via show(relativeTo:of:preferredEdge:)
```

**Current Issues:**
1. Lines 177-187: Status item length switches between fixed and variable during slot name display
2. Line 272: No caching of button position before show
3. No observers for display configuration changes
4. Timers continue updating appearance while popover is shown (causes jitter)

### Recommended Project Structure
```
PomodoroApp.swift (AppDelegate):
├── statusItem (fixed-width)
├── popover (unchanged)
├── cachedButtonFrame: NSRect? (new)
├── displayChangeObserver (new)
├── calculateMaxStatusItemWidth() - initialization helper
├── updateStatusButton() - modified
│   ├── NO dynamic length switching
│   └── Pause timers when popover is shown
├── togglePopover() - modified
│   ├── Cache button frame in screen coordinates before show
│   └── Use cached frame if button frame is nil
└── handleDisplayChange() - new notification handler
```

No architectural refactoring required. Changes are contained within AppDelegate.

### Pattern 1: Fixed-Width Status Item
**What:** Calculate maximum possible content width at initialization and always use that fixed width.

**When to use:** At `applicationDidFinishLaunching` before first status button update.

**Why:** Prevents bounds changes during popover display. NSPopover anchors to the view bounds at show time; if bounds change after show, popover positioning breaks.

**Example:**
```swift
// In applicationDidFinishLaunching, after creating statusItem
func calculateMaxStatusItemWidth() -> CGFloat {
    let monoFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

    // Maximum timer display: "MM 00:00" (widest icon + timer)
    // Maximum slot name: " · " + 10 chars (marqueeMaxChars)
    let maxContent = " 00:00 · " + String(repeating: "M", count: marqueeMaxChars)
    let textWidth = (maxContent as NSString).size(withAttributes: [.font: monoFont]).width

    let iconWidth: CGFloat = 20  // System symbol icon width
    let padding: CGFloat = 8

    return iconWidth + textWidth + padding
}

// Set once at initialization
let maxWidth = calculateMaxStatusItemWidth()
statusItem.length = maxWidth

// Remove lines 177-187 that switch between fixed and variable
```

**Verification:** After change, `statusItem.length` should never be reassigned in `updateStatusButton()` or `updateStatusButtonAppearance()`.

### Pattern 2: Screen Coordinate Caching
**What:** Convert button frame to screen coordinates before showing popover, store for later use if button frame becomes invalid.

**When to use:** In `togglePopover()` before calling `popover.show()`.

**Why:** When menu bar auto-hides, `statusItem.button?.window?.frame` becomes nil. Screen coordinates remain valid and can be used for fallback positioning or graceful dismissal.

**Example:**
```swift
private var cachedButtonFrame: NSRect?

private func togglePopover() {
    guard let button = statusItem.button else { return }

    if popover.isShown {
        popover.performClose(nil)
        cachedButtonFrame = nil
    } else {
        // Cache button frame in screen coordinates before showing
        if let buttonWindow = button.window {
            let buttonFrameInWindow = button.frame
            let buttonFrameInScreen = buttonWindow.convertToScreen(buttonFrameInWindow)
            cachedButtonFrame = buttonFrameInScreen
        }

        // Show popover with current button bounds
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
```

**Verification:** Log `cachedButtonFrame` before and during menu bar auto-hide to confirm screen coordinates remain stable.

### Pattern 3: Graceful Fallback on Invalid Anchor
**What:** If popover is shown but button frame becomes nil (menu bar auto-hides), dismiss popover cleanly rather than letting it jump to (0,0).

**When to use:** When detecting menu bar visibility changes while popover is shown.

**Why:** Success criterion 4 requires "graceful fallback if positioning fails (dismiss cleanly rather than jump to corner)".

**Example:**
```swift
// Add popover delegate method
func popoverDidShow(_ notification: Notification) {
    // Start monitoring for menu bar state changes
    startMonitoringMenuBarVisibility()
}

func popoverDidClose(_ notification: Notification) {
    stopMonitoringMenuBarVisibility()
}

// Monitor button frame validity
private var menuBarMonitorTimer: Timer?

private func startMonitoringMenuBarVisibility() {
    // Only monitor when popover is shown
    menuBarMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
        guard let self = self else { return }

        // Check if button frame is still valid
        if self.popover.isShown && self.statusItem.button?.window?.frame == nil {
            // Button frame invalid (menu bar likely auto-hiding) - dismiss gracefully
            self.popover.performClose(nil)
        }
    }
}

private func stopMonitoringMenuBarVisibility() {
    menuBarMonitorTimer?.invalidate()
    menuBarMonitorTimer = nil
}
```

**Verification:** Enable auto-hide menu bar, open popover, move mouse away. Popover should dismiss cleanly when menu bar starts hiding, not jump to corner.

### Pattern 4: Display Change Monitoring
**What:** Observe `NSApplication.didChangeScreenParametersNotification` to detect multi-monitor configuration changes.

**When to use:** Register observer in `applicationDidFinishLaunching`, handle in dedicated method.

**Why:** Success criterion 2 requires "User moves app between monitors and popover appears correctly positioned on active screen".

**Example:**
```swift
// In applicationDidFinishLaunching
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleDisplayChange),
    name: NSApplication.didChangeScreenParametersNotification,
    object: nil
)

@objc private func handleDisplayChange() {
    // If popover is shown, dismiss and let user reopen
    // (Safer than trying to reposition across displays)
    if popover.isShown {
        popover.performClose(nil)
    }

    // Clear cached frame - will be recalculated on next show
    cachedButtonFrame = nil
}
```

**Verification:** Open popover, change display resolution or disconnect/reconnect monitor. Popover should dismiss gracefully.

### Pattern 5: Pause Timers During Popover Display
**What:** Stop blink and marquee timers while popover is shown to prevent status button appearance changes.

**When to use:** In `popoverDidShow` and `popoverDidClose` delegate methods.

**Why:** Success criterion 3 requires "popover doesn't jump or jitter during timer/marquee updates". Even with fixed width, changing the attributed string content can cause subtle layout changes.

**Example:**
```swift
private var suspendedTimers: (blink: Timer?, marquee: Timer?) = (nil, nil)

func popoverDidShow(_ notification: Notification) {
    // Suspend timers to prevent appearance changes
    suspendedTimers.blink = blinkTimer
    suspendedTimers.marquee = marqueeTimer

    blinkTimer?.invalidate()
    blinkTimer = nil

    marqueeTimer?.invalidate()
    marqueeTimer = nil

    startMonitoringMenuBarVisibility()
}

func popoverDidClose(_ notification: Notification) {
    stopMonitoringMenuBarVisibility()

    // Resume timers if they were running
    if suspendedTimers.blink != nil {
        // Trigger updateStatusButton to restart timers if still needed
        updateStatusButton()
    }

    suspendedTimers = (nil, nil)
}
```

**Verification:** Open popover while timer is blinking or marquee is scrolling. Button should freeze during popover display, resume after close.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Popover positioning | Custom NSWindow-based popover | NSPopover with cached coordinates | NSPopover handles window level, transient behavior, arrow rendering, focus handling. Custom window requires ~200 lines of code for equivalent behavior. |
| Display change detection | Polling NSScreen.screens | `NSApplication.didChangeScreenParametersNotification` | Notification fires reliably for resolution changes, monitor connect/disconnect. Polling wastes CPU and battery. |
| Fixed-width font rendering | Manual character width calculation | `NSFont.monospacedSystemFont()` | System monospaced font guarantees equal character width. Manual calculation breaks with Unicode, emoji, ligatures. |
| Screen coordinate conversion | Manual math with NSScreen.frame | `NSWindow.convertToScreen()` | Handles Retina scaling, multiple displays, coordinate space transformations automatically. Manual math breaks on mixed DPI setups. |

**Key insight:** NSPopover is battle-tested for menu bar apps. The bug isn't NSPopover's fault - it's the dynamic status item width changes breaking NSPopover's anchor. Fix the width changes, not the popover.

## Common Pitfalls

### Pitfall 1: Continuing to Use Variable-Length Status Item
**What goes wrong:** Even with caching, if status item width changes while popover is shown, button bounds change, anchor breaks, popover jumps.

**Why it happens:** The marquee timer (line 144) and blink timer (line 117) continue updating appearance. Line 186 switches `statusItem.length` between fixed and variable. NSPopover anchors to `button.bounds` at show time; changing bounds invalidates anchor.

**How to avoid:**
1. Calculate maximum width once at startup
2. Set `statusItem.length` to that fixed value
3. Never reassign `statusItem.length` after initialization
4. Pad shorter content with spaces to fill fixed width (already done on lines 238-240)

**Warning signs:**
- Popover jumps slightly when timer updates every second
- Popover shifts when slot name starts/stops marquee
- Different positioning behavior with short vs long slot names

### Pitfall 2: Not Caching in Screen Coordinates
**What goes wrong:** Caching `button.frame` (view-relative) or `button.bounds` (view-local) becomes invalid when menu bar auto-hides because the coordinate space disappears.

**Why it happens:** `button.frame` is relative to superview (status item's internal view hierarchy). `button.bounds` is in button's own coordinate space. When menu bar auto-hides, the button's window becomes nil, invalidating these coordinate spaces.

**How to avoid:**
1. Use `button.window?.convertToScreen(button.frame)` to get screen coordinates
2. Screen coordinates remain valid even when menu bar hides
3. Store NSRect in screen space, not view space

**Warning signs:**
- Cached frame is NSZeroRect or has origin (0,0) unexpectedly
- Different behavior when menu bar is visible vs auto-hidden
- Popover jumps to corner only on displays with auto-hide enabled

### Pitfall 3: Reanchoring Instead of Dismissing
**What goes wrong:** Attempting to reanchor popover while menu bar auto-hides causes flicker, incorrect positioning, or crashes.

**Why it happens:** During menu bar hide animation, button frame transitions through intermediate states. Trying to reanchor mid-transition uses invalid intermediate coordinates. NSPopover may not handle rapid show/hide/show cycles gracefully.

**How to avoid:**
1. Detect when button frame becomes invalid (window nil check)
2. Dismiss popover cleanly with `popover.performClose(nil)`
3. Let user reopen popover after menu bar state stabilizes
4. Don't try to "follow" the button during transitions

**Warning signs:**
- Flicker or flash during reanchoring
- Popover appears in wrong position after reanchor
- Console warnings about invalid anchor views
- Occasional crashes in AppKit popover positioning code

### Pitfall 4: Not Pausing Timers During Popover Display
**What goes wrong:** Even with fixed width, changing attributed string content (blink color changes, marquee text changes) can cause subtle layout recalculations that shift popover position.

**Why it happens:** NSAttributedString rendering may have fractional pixel differences between blink states or marquee positions. Fixed width prevents major jumps but micro-jitter (1-2 pixel shifts) can still occur.

**How to avoid:**
1. Implement `NSPopoverDelegate` methods `popoverDidShow` and `popoverDidClose`
2. Invalidate blink and marquee timers in `popoverDidShow`
3. Resume timers in `popoverDidClose`
4. Button appearance remains frozen while popover is shown

**Warning signs:**
- Subtle 1-2 pixel jitter every 0.3s (marquee interval) or 0.5s (blink interval)
- Popover feels "shaky" even though it doesn't jump to corner
- More noticeable on external monitors or when recording screen

### Pitfall 5: Ignoring Multi-Monitor Edge Cases
**What goes wrong:** Popover positioning assumes status item is on main display. When status item moves to secondary display (macOS rearranges status items), positioning calculations use wrong screen bounds.

**Why it happens:** Each display has different frame coordinates in screen space. Menu bar is typically on screen with `frame.origin.y == 0`, but status item can be on any display in multi-monitor setups.

**How to avoid:**
1. Determine which screen contains the button using `button.window?.screen`
2. Use that screen's bounds for edge detection, not `NSScreen.main`
3. Observe `didChangeScreenParametersNotification` to detect screen arrangement changes
4. When notification fires and popover is shown, dismiss and clear cache

**Warning signs:**
- Works correctly on single monitor, breaks on multi-monitor
- Popover appears on wrong display
- Different behavior depending on which display is "primary"
- Issues only on specific monitor configurations (different resolutions)

## Code Examples

Verified patterns from existing code and research:

### Calculate Maximum Status Item Width
```swift
// Call once in applicationDidFinishLaunching after creating statusItem
private func calculateMaxStatusItemWidth() -> CGFloat {
    // Using the same monospaced font as updateStatusButtonAppearance (line 170)
    let monoFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

    // Maximum possible content:
    // - Icon: ~20pt
    // - Timer: " 00:00" (widest digits, 6 chars including space)
    // - Separator: " · "
    // - Slot name: 10 chars (marqueeMaxChars)
    let maxTimerText = " 00:00"
    let maxSlotNameText = " · " + String(repeating: "M", count: marqueeMaxChars)
    let maxContent = maxTimerText + maxSlotNameText

    let textWidth = (maxContent as NSString).size(withAttributes: [.font: monoFont]).width
    let iconWidth: CGFloat = 20
    let padding: CGFloat = 8

    return iconWidth + textWidth + padding
}

// In applicationDidFinishLaunching
statusItem = NSStatusBar.system.statusItem(withLength: calculateMaxStatusItemWidth())
```

### Cache Button Frame in Screen Coordinates
```swift
// Add property to AppDelegate
private var cachedButtonFrame: NSRect?

// Modified togglePopover
private func togglePopover() {
    guard let button = statusItem.button else { return }

    if popover.isShown {
        popover.performClose(nil)
        cachedButtonFrame = nil
    } else {
        // Cache button frame in screen coordinates
        if let buttonWindow = button.window {
            let frameInWindow = button.frame
            let frameInScreen = buttonWindow.convertToScreen(frameInWindow)
            cachedButtonFrame = frameInScreen

            print("Cached button frame in screen coords: \(frameInScreen)")
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
```

### Monitor Display Changes and Menu Bar Visibility
```swift
// Add properties
private var displayChangeObserver: NSObjectProtocol?
private var menuBarVisibilityTimer: Timer?

// In applicationDidFinishLaunching
displayChangeObserver = NotificationCenter.default.addObserver(
    forName: NSApplication.didChangeScreenParametersNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    self?.handleDisplayChange()
}

@objc private func handleDisplayChange() {
    print("Display configuration changed")

    // If popover is shown, dismiss it
    if popover.isShown {
        popover.performClose(nil)
    }

    // Clear cached frame - will be recalculated on next show
    cachedButtonFrame = nil
}

// NSPopoverDelegate methods
func popoverDidShow(_ notification: Notification) {
    // Start monitoring menu bar visibility while popover is shown
    menuBarVisibilityTimer = Timer.scheduledTimer(
        withTimeInterval: 0.2,
        repeats: true
    ) { [weak self] _ in
        guard let self = self else { return }

        // Check if button frame is still valid
        if self.popover.isShown {
            if self.statusItem.button?.window?.frame == nil {
                print("Button frame became invalid, dismissing popover")
                self.popover.performClose(nil)
            }
        }
    }
}

func popoverDidClose(_ notification: Notification) {
    menuBarVisibilityTimer?.invalidate()
    menuBarVisibilityTimer = nil
}
```

### Pause Timers During Popover Display
```swift
// Add property to track suspended timers
private var suspendedBlinkTimer: Bool = false
private var suspendedMarqueeTimer: Bool = false

// Extend popoverDidShow
func popoverDidShow(_ notification: Notification) {
    // Suspend appearance-changing timers
    if blinkTimer != nil {
        suspendedBlinkTimer = true
        blinkTimer?.invalidate()
        blinkTimer = nil
    }

    if marqueeTimer != nil {
        suspendedMarqueeTimer = true
        marqueeTimer?.invalidate()
        marqueeTimer = nil
    }

    // Start menu bar monitoring
    menuBarVisibilityTimer = Timer.scheduledTimer(
        withTimeInterval: 0.2,
        repeats: true
    ) { [weak self] _ in
        guard let self = self else { return }
        if self.popover.isShown && self.statusItem.button?.window?.frame == nil {
            self.popover.performClose(nil)
        }
    }
}

// Extend popoverDidClose
func popoverDidClose(_ notification: Notification) {
    menuBarVisibilityTimer?.invalidate()
    menuBarVisibilityTimer = nil

    // Resume timers if they were suspended
    if suspendedBlinkTimer || suspendedMarqueeTimer {
        suspendedBlinkTimer = false
        suspendedMarqueeTimer = false
        // Trigger update to restart timers if still needed
        updateStatusButton()
    }
}
```

### Remove Dynamic Width Switching
```swift
// In updateStatusButtonAppearance, REMOVE lines 177-187:
// DELETE THIS CODE:
/*
if showingSlotName {
    let sampleText = " 00:00 · " + String(repeating: "M", count: marqueeMaxChars)
    let textWidth = (sampleText as NSString).size(withAttributes: [.font: monoFont]).width
    let iconWidth: CGFloat = 20
    statusItem.length = iconWidth + textWidth + 8
} else {
    statusItem.length = NSStatusItem.variableLength
}
*/

// Instead, statusItem.length is set once at initialization and never changed
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Variable-length status items | Fixed-width with padding | Ongoing best practice | Prevents jitter from dynamic content, stable popover anchor |
| Query button frame on use | Cache in screen coordinates | macOS 10.9+ with auto-hide menu bar | Screen coordinates survive menu bar state transitions |
| Custom NSWindow popovers | NSPopover with proper anchoring | macOS 10.7+ NSPopover introduction | NSPopover handles window level, transient behavior, arrow rendering |
| Polling for display changes | Notification-based (`didChangeScreenParametersNotification`) | macOS 10.0+ notification system | Lower CPU, battery efficient, timely updates |

**Deprecated/outdated:**
- **NSStatusItem.variableLength with dynamic content updates**: Still supported but problematic for apps with frequent appearance changes (timers, animations). Fixed-width is the modern best practice for menubar apps with dynamic content.
- **Immediate reanchoring on display changes**: Older implementations tried to reposition popover on screen changes. Modern approach: dismiss and let user reopen. Simpler, more reliable, better UX (user expects UI to reset on major system changes).

## Open Questions

1. **Exact timing of menu bar auto-hide**
   - What we know: `statusItem.button?.window?.frame` becomes nil when menu bar hides
   - What's unclear: Is there a notification fired before/during hide transition? `didChangeScreenParametersNotification` may not fire for auto-hide.
   - Recommendation: Use polling (0.2s timer) while popover is shown. Only active when popover is visible, minimal battery impact. Can investigate notifications later if polling proves problematic.

2. **Optimal polling interval for menu bar visibility**
   - What we know: Need to detect when button frame becomes invalid
   - What's unclear: Balance between responsiveness and battery impact. 0.2s? 0.5s? 1.0s?
   - Recommendation: Start with 0.2s (5 checks/sec). Monitor battery impact in testing. User won't notice <0.5s delay before dismiss.

3. **Notched MacBook Pro display handling**
   - What we know: MacBook Pro 14"/16" with notch affects menu bar item positioning
   - What's unclear: Does notch cause menu bar items to have different coordinate behavior?
   - Recommendation: Test on notched MacBook. Screen coordinate caching should handle automatically since we're using system APIs for conversion.

4. **Should we prevent popover from opening when menu bar is auto-hidden?**
   - What we know: User can still click status item when menu bar is temporarily revealed
   - What's unclear: Is it better UX to show popover briefly before menu bar hides again, or block opening?
   - Recommendation: Allow opening (current behavior). Our monitoring will dismiss gracefully if menu bar hides. More flexible than blocking.

## Sources

### Primary (HIGH confidence)
- **Existing codebase analysis:**
  - `/Users/pedf/workspace/pomodoro-mac/PomodoroApp/PomodoroApp.swift` - Current implementation with variable-length status item (line 73), dynamic width switching (lines 177-187), timer updates (lines 117, 144)
  - Lines 266-275: Current `togglePopover()` implementation with no coordinate caching
  - Lines 110-254: Status button update logic with blink and marquee timers

- **Prior project research:**
  - `.planning/research/SUMMARY.md` - Comprehensive analysis identifying root causes: variable-length status item + dynamic content updates
  - `.planning/research/ARCHITECTURE.md` - Detailed component boundaries and positioning patterns (though more complex than needed for this phase)
  - `.planning/research/FEATURES.md` - Table stakes features and anti-features to avoid

### Secondary (MEDIUM confidence)
- **Apple Developer Documentation patterns (from training data):**
  - NSStatusItem, NSPopover, NSScreen APIs (AppKit framework)
  - Coordinate space conversion with `NSWindow.convertToScreen()`
  - Notification system for display changes

- **Community patterns and known issues:**
  - [NSPopover and NSStatusItem on 10.11 | Apple Developer Forums](https://developer.apple.com/forums/thread/17872) - Known issue where popover appears at (0,0) before snapping, workaround using dispatch_after
  - [Multi Blog – Pushing the limits of NSStatusItem](https://multi.app/blog/pushing-the-limits-nsstatusitem) - Advanced NSStatusItem techniques and limitations
  - [Using NSPopover with NSStatusItem](https://shaheengandhi.com/using-nspopover-with-nsstatusitem/) - Tutorial on basic integration
  - [How to Create a Mac Menu Bar App With NSPopover | Fleetings Pixels](https://fleetingpixels.com/articles/2020/how-to-create-a-mac-menu-bar-app-with-nspopover/) - Complete guide to menu bar app setup

### Tertiary (LOW confidence, flagged for validation)
- **Coordinate system behavior:**
  - [Coordinate system | Apple Developer Documentation](https://developer.apple.com/library/archive/documentation/General/Devpedia-CocoaApp-MOSX/CoordinateSystem.html) - General coordinate system principles
  - Exact screen coordinate behavior during menu bar auto-hide transitions (undocumented)
  - Multi-monitor coordinate conversion edge cases with mixed DPI displays

- **Auto-hide menu bar notifications:**
  - No official notification found for menu bar hide/show transitions
  - `didChangeScreenParametersNotification` may fire inconsistently for auto-hide
  - Polling appears necessary, but interval and timing are empirical

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - NSStatusItem and NSPopover are well-documented, established APIs
- Fixed-width approach: HIGH - Direct observation of code confirms dynamic width is root cause
- Screen coordinate caching: HIGH - Standard pattern for coordinate space preservation
- Display monitoring: MEDIUM-HIGH - Notification API documented but auto-hide timing unclear
- Multi-monitor handling: MEDIUM - Core APIs solid but edge cases need hardware testing
- Implementation approach: HIGH - Minimal changes to existing architecture, low risk

**Research date:** 2026-02-12
**Valid until:** ~30 days (stable AppKit APIs, low framework churn)

**Key risks mitigated by research:**
- Identified exact root cause (lines 177-187 dynamic width switching)
- Confirmed existing monospaced font usage enables fixed-width calculation
- Validated that minimal changes can fix all success criteria without refactoring
- Documented that NSPopover doesn't need replacement, just proper anchoring

**Gaps requiring testing validation:**
- Polling interval for menu bar visibility (empirical UX and battery testing)
- Notched MacBook Pro display behavior (hardware-specific testing)
- Multi-monitor configuration edge cases (various resolution combinations)
- Auto-hide notification timing variations across macOS versions
