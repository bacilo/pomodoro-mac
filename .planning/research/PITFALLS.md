# Domain Pitfalls: macOS Menubar App Popover Positioning

**Domain:** macOS menubar app popovers with auto-hiding menu bars
**Researched:** 2026-02-12

## Critical Pitfalls

Mistakes that cause rewrites or major issues.

### Pitfall 1: Assuming Status Item Frame is Always Valid
**What goes wrong:** Code reads statusItem.button?.window?.frame when needed, but returns nil or (0,0) after menu bar hides, causing popover to jump to screen origin.

**Why it happens:** NSStatusBar is a special window that disappears completely when auto-hide menu bar hides. The button's window property becomes nil, and frame lookups fail.

**Consequences:**
- Popover jumps to top-left corner (0,0 in screen coordinates)
- User loses context and has to reopen
- Makes app feel broken and unprofessional

**Prevention:**
```swift
// BAD - reads frame every time
func showPopover() {
    guard let button = statusItem.button else { return }
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    // Frame is captured here, but may become invalid later
}

// GOOD - cache frame in screen coordinates when valid
var cachedStatusItemFrame: NSRect?

func showPopover() {
    guard let button = statusItem.button else { return }
    // Cache IMMEDIATELY when we know it's valid
    cachedStatusItemFrame = button.window?.frame
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
}

func repositionIfNeeded() {
    // Use cached frame if current frame is invalid
    if statusItem.button?.window == nil, let cached = cachedStatusItemFrame {
        // Position using cached coordinates
    }
}
```

**Detection:**
- Bug reports about popover jumping to corner
- Console logs showing NSPopover anchor view warnings
- Visible only on displays with auto-hide menu bar enabled

### Pitfall 2: Using Window Coordinates Instead of Screen Coordinates
**What goes wrong:** Storing position relative to status bar window, which disappears, making relative coordinates meaningless.

**Why it happens:** Natural instinct to use relative positioning, but the parent coordinate system vanishes.

**Consequences:**
- Position calculations fail completely
- May crash with nil window reference
- Can't restore position when menu bar reappears

**Prevention:**
- Always convert to screen coordinates immediately
- NSScreen coordinate system is stable (origin at bottom-left of primary screen)
- Store absolute screen coordinates, not relative positions

```swift
// BAD
let localFrame = button.frame // in button's window coordinates

// GOOD
let screenFrame = button.window?.convertToScreen(button.frame) // absolute
```

**Detection:**
- Position calculations that work with visible menu bar but fail when hidden
- Console warnings about invalid coordinate conversions

### Pitfall 3: Over-Relying on Notifications
**What goes wrong:** Waiting for NSApplication.didChangeScreenParametersNotification to detect menu bar hide/show, but notification timing is inconsistent and may not fire for all auto-hide transitions.

**Why it happens:** Notifications seem like the "proper" way to detect changes, but menu bar auto-hide is driven by mouse position, not system state changes.

**Consequences:**
- Missed repositioning opportunities
- Popover still jumps because notification never arrives
- Inconsistent behavior across macOS versions

**Prevention:**
- Use notifications as ONE signal, not the only signal
- Implement fallback detection (check frame validity before use)
- Consider timer-based validation if critical

```swift
// BAD - only source of truth
NotificationCenter.default.addObserver(
    forName: NSApplication.didChangeScreenParametersNotification,
    // Only repositions when notification fires - may miss events
)

// GOOD - defensive programming
func updatePopoverPosition() {
    // Check validity first
    if let currentFrame = statusItem.button?.window?.frame {
        cachedFrame = currentFrame
    } else if let cached = cachedFrame {
        // Use cached - anchor is gone
        repositionToScreen(cached)
    } else {
        // Fallback: dismiss or position at default location
    }
}
```

**Detection:**
- Intermittent failures
- Works on some displays but not others
- Timing-dependent bugs

## Moderate Pitfalls

### Pitfall 4: Forgetting Multi-Monitor Scenarios
**What goes wrong:** Solution works on single display but breaks when status item moves to different screen or screen configuration changes.

**Prevention:**
- Always determine which NSScreen contains the status item
- Recalculate when screen layout changes
- Don't assume status item is on main screen

### Pitfall 5: Hardcoded Offsets for Menu Bar Height
**What goes wrong:** Assuming menu bar is always 24pt high, but Retina displays, notched MacBooks, and accessibility settings vary.

**Prevention:**
- Calculate menu bar height from actual window frame
- Use NSScreen.frame and NSScreen.visibleFrame difference
- Don't rely on magic numbers

### Pitfall 6: Not Handling Screen Edge Cases
**What goes wrong:** Popover positioned off-screen when status item is near screen edge.

**Prevention:**
- Let NSPopover handle edge detection with preferredEdge
- Verify final popover position is within screen bounds
- Provide fallback edges if preferred edge doesn't fit

### Pitfall 7: Race Conditions with Popover Show/Hide
**What goes wrong:** Trying to reposition while popover is in transition state between showing and hiding.

**Prevention:**
- Check popover.isShown before repositioning
- Coordinate with popover delegate methods
- Avoid repositioning during willShow/didShow transitions

## Minor Pitfalls

### Pitfall 8: Memory Leaks from Notification Observers
**What goes wrong:** Adding notification observers but not removing them properly.

**Prevention:**
- Use weak references in closures
- Remove observers in deinit
- Consider using Combine or modern observation patterns

### Pitfall 9: Performance Impact of Continuous Polling
**What goes wrong:** Checking frame validity every render cycle or very frequently.

**Prevention:**
- Only check on specific events (mouse moved, popover will show)
- Use debouncing if polling is necessary
- Profile to ensure no performance degradation

### Pitfall 10: Ignoring Dark Mode and UI Scale
**What goes wrong:** Position calculations don't account for display scaling or appearance changes.

**Prevention:**
- Use native coordinate systems (they handle scaling)
- Avoid pixel-based calculations
- Test on Retina and non-Retina displays

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Initial implementation | Thinking frame caching alone is sufficient | Add notification observation and validity checks |
| Testing | Only testing on primary display with visible menu bar | Test matrix: auto-hide on/off × primary/secondary display |
| Multi-monitor support | Assuming screen indices are stable | Use NSScreen.deviceDescription matching, not array index |
| Edge cases | Not handling status item moving between screens | Observe NSStatusItem position changes if possible |
| Performance | Checking frame validity too frequently | Event-driven approach, not polling |

## Debugging Strategies

### When Popover Position is Wrong

1. **Log coordinate spaces:**
   ```swift
   print("Button frame: \(button.frame)")
   print("Window frame: \(button.window?.frame)")
   print("Screen frame: \(button.window?.screen?.frame)")
   ```

2. **Check anchor validity:**
   ```swift
   print("Button has window: \(button.window != nil)")
   print("Popover is shown: \(popover.isShown)")
   ```

3. **Verify screen detection:**
   ```swift
   print("Status item screen: \(button.window?.screen?.localizedName)")
   print("All screens: \(NSScreen.screens.map { $0.localizedName })")
   ```

### When Notifications Don't Fire

1. Test manually hiding menu bar (move mouse away)
2. Check observer is registered before event occurs
3. Try alternative notifications (NSWindow.didChangeScreenNotification)
4. Add notification logging to see what DOES fire

### When Multi-Monitor Fails

1. Identify which screen contains status item
2. Check screen arrangement in System Preferences
3. Verify coordinate conversion between screens
4. Test with displays of different resolutions

## Testing Checklist

Essential scenarios to verify fix works:

- [ ] Single display, menu bar always visible (baseline)
- [ ] Single display, menu bar auto-hide enabled
- [ ] Multi-monitor, auto-hide on primary only
- [ ] Multi-monitor, auto-hide on secondary only
- [ ] Status item moves to different screen during popover display
- [ ] Display disconnected while popover open
- [ ] Display resolution change while popover open
- [ ] Rapid menu bar show/hide cycles
- [ ] Popover opened via keyboard shortcut (no mouse position)
- [ ] Different macOS versions if supporting multiple

## Red Flags During Implementation

Watch for these warning signs:

🚩 "It works on my machine" - likely testing with visible menu bar only
🚩 Hardcoded coordinates (like `NSPoint(x: 100, y: 100)`)
🚩 Force-unwrapping frame values (`button.window!.frame`)
🚩 No null checks before using cached frames
🚩 Repositioning every 0.1 seconds (performance issue brewing)
🚩 Ignoring NSPopover delegate warnings in console
🚩 No testing on actual auto-hide configuration

## Recovery Patterns

When all else fails, have a fallback:

```swift
func showPopoverSafely() {
    if let validFrame = getValidStatusItemFrame() {
        // Preferred: show relative to status item
        showAtFrame(validFrame)
    } else {
        // Fallback 1: Center on screen with status item
        showAtScreenCenter(screenContainingStatusItem())
    } else {
        // Fallback 2: Center on main screen
        showAtScreenCenter(NSScreen.main)
    } else {
        // Fallback 3: Dismiss gracefully
        print("Cannot determine popover position, dismissing")
        closePopover()
    }
}
```

Graceful degradation is better than jumping to (0,0).

## Sources

Based on:
- Common AppKit NSStatusItem + NSPopover implementation patterns
- Known issues with menu bar auto-hide documented in developer forums
- Coordinate system behavior in macOS window management
- Testing scenarios from multi-monitor app development

**Note:** Specific notification timing and edge cases should be verified through empirical testing on target macOS versions.
