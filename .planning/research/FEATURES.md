# Feature Landscape: macOS Menubar App Popover Positioning

**Domain:** macOS menubar app popovers with auto-hiding menu bars
**Researched:** 2026-02-12
**Confidence:** MEDIUM (based on training data and established macOS HIG patterns)

## Table Stakes

Features users expect. Missing = product feels incomplete or buggy.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Popover stays near status item | Core expectation - popover should appear relative to its trigger | Low | Standard NSPopover behavior when menu bar is visible |
| Popover doesn't jump on menu bar hide | User expects popover to remain stable during interaction | Medium | Requires tracking position before menu bar hides |
| Works across all displays | Multi-monitor setups are standard for many users | Medium | Each display can have different auto-hide settings |
| Respects screen edges | Popover should stay on-screen, not clip off edges | Low | NSPopover handles this automatically with preferredEdge |
| Consistent anchor point | Popover should always appear in predictable location relative to icon | Medium | Requires calculating correct positioning rect |
| Auto-hide menu bar detection | App should know when running on display with auto-hide enabled | Low | Check NSScreen properties and NSApplication.presentationOptions |
| Window level management | Popover should stay visible above other windows but not interfere | Low | NSPopover handles this with .popover window level |

## Differentiators

Features that set product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Smooth position transitions | Graceful animation if position adjustment needed | Medium | Custom animation between old/new anchor points |
| Remember last screen position | Re-open on same display where user last used it | Low | Store NSScreen identifier in UserDefaults |
| Smart edge detection | Automatically flip popover to other side if near screen edge | Low | Use NSPopover.behavior and preferredEdge |
| Mouse tracking awareness | Keep popover open while mouse is nearby, even if menu bar hides | High | Requires custom mouse tracking region monitoring |
| Keyboard shortcut positioning | If opened via keyboard, position near current mouse/focused window | Medium | Different UX path than click-to-open |
| Multi-monitor awareness indicator | Visual feedback showing which display is active | Low | Helpful for debugging but rarely needed in production |

## Anti-Features

Features to explicitly NOT build (or behaviors causing the reported bug).

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Relying solely on status item frame | Status item frame becomes invalid when menu bar auto-hides | Calculate and cache position before menu bar hides |
| Using window-relative coordinates | Menu bar window disappears on auto-hide, making window coordinates unstable | Use screen coordinates and convert appropriately |
| Showing popover directly from MenuBarExtra button | SwiftUI MenuBarExtra may not provide stable anchor in all scenarios | Consider NSStatusItem-based approach or custom positioning |
| Re-anchoring on every frame | Continuous repositioning causes jitter and performance issues | Only reposition on specific events (display change, menu bar show/hide) |
| Hardcoded offset values | Different macOS versions and display configurations vary | Calculate dynamically based on actual menu bar height and status item position |
| Ignoring NSScreen.frame changes | Screen configuration changes aren't just multi-monitor; includes resolution, rotation | Observe screen parameter change notifications |
| Keeping popover open indefinitely on auto-hide displays | User may expect popover to dismiss when menu bar hides (like native behavior) | Offer configurable behavior or match system conventions |

## Feature Dependencies

```
Auto-hide detection → Position caching (need to know when to cache)
Position caching → Smooth transitions (need old position to animate from)
Multi-display support → Screen edge detection (each screen has different bounds)
Window level management → Mouse tracking (both affect popover visibility hierarchy)
```

## Technical Implementation Patterns

### Pattern 1: Status Item Frame Caching
**Problem:** NSStatusItem.button?.window?.frame becomes nil/invalid when menu bar auto-hides
**Solution:** Cache the frame in screen coordinates when popover opens, before menu bar might hide
**Complexity:** Low
**Code approach:**
```swift
// Cache when popover opens
let statusItemFrame = statusItem.button?.window?.frame
let screenFrame = statusItemFrame // Already in screen coordinates

// Use cached frame for positioning even after menu bar hides
```

### Pattern 2: Custom NSWindow Instead of NSPopover
**Problem:** NSPopover relies on anchor view, which may disappear
**Solution:** Use custom NSWindow with .hudWindow style and manual positioning
**Complexity:** High
**Tradeoff:** More control but loses NSPopover's built-in behaviors (arrow, auto-dismissal)

### Pattern 3: Notification-Based Repositioning
**Problem:** Need to know when menu bar visibility changes
**Solution:** Observe NSApplication.didChangeScreenParametersNotification
**Complexity:** Low
**Limitation:** May not fire for all auto-hide transitions

### Pattern 4: Periodic Position Validation
**Problem:** Menu bar can hide/show based on mouse position without notifications
**Solution:** Timer-based validation of anchor point availability
**Complexity:** Medium
**Tradeoff:** More robust but uses more CPU

### Pattern 5: SwiftUI Window-Based Popover
**Problem:** MenuBarExtra with .window style gives more control than .menu
**Solution:** Use MenuBarExtra(content:label:) with window-based content
**Complexity:** Medium (SwiftUI only)
**Note:** Available macOS 13.0+, may have better auto-hide handling

## Multi-Monitor Specific Features

### Essential
- Detect which screen contains the status item
- Handle status item moving between screens (user drags to different display)
- Handle screen resolution/bounds changes
- Respect per-screen auto-hide settings

### Nice-to-Have
- Remember last used screen
- Optimize for primary vs secondary display differences
- Handle edge case: status item on one screen, user triggers via keyboard while focused on another

## MVP Recommendation

Prioritize (in order):

1. **Auto-hide detection** - Low complexity, high impact. Know the environment.
2. **Position caching in screen coordinates** - Medium complexity, directly fixes the bug.
3. **NSApplication.didChangeScreenParametersNotification observation** - Low complexity, enables responsive behavior.
4. **Fallback positioning strategy** - Medium complexity, ensures graceful degradation.
5. **Screen edge detection** - Low complexity, prevents off-screen popover.

Defer:
- **Smooth transitions** - Polish feature, fix jumping first
- **Mouse tracking awareness** - High complexity, uncertain value
- **Remember last screen** - Useful but not critical for bug fix

## Testing Scenarios

Critical test cases for this feature domain:

1. Open popover on display with auto-hide menu bar enabled
2. Move mouse away to trigger menu bar hide while popover is open
3. Multi-monitor: one with auto-hide, one without
4. Status item moves to different screen (macOS reorganizes status items)
5. Screen resolution change while popover is open
6. External display connected/disconnected
7. Display arrangement change in System Preferences
8. Spaces/desktop switching with popover open

## Known macOS Behavior Variations

- **macOS 13.0+**: MenuBarExtra with window style provides better control
- **macOS 12.x and earlier**: Must use NSStatusItem + NSPopover approach
- **Menu bar height**: Standard 24pt, but Retina vs non-Retina affects coordinates
- **Notch displays**: MacBook Pro models with notch affect status item positioning

## Confidence Assessment

- **Pattern identification**: MEDIUM - Based on established AppKit patterns and developer community knowledge
- **macOS version differences**: MEDIUM - Training data covers documented APIs through macOS 13-14
- **SwiftUI MenuBarExtra specifics**: LOW - SwiftUI menubar APIs are evolving, would benefit from official docs verification
- **Auto-hide notification timing**: LOW - Exact notification behavior not well-documented, needs empirical testing

## Sources

**Note:** Research tools were unavailable. This analysis is based on:
- Apple's Human Interface Guidelines for macOS
- AppKit NSStatusItem and NSPopover documentation patterns
- SwiftUI MenuBarExtra APIs (macOS 13.0+)
- Common patterns from macOS menubar app development

**Recommended verification:**
- Official Apple documentation for NSStatusItem.button frame behavior during auto-hide
- Real-world testing on macOS 13+ with various display configurations
- Community implementations (GitHub examples of menubar apps handling auto-hide)

## Gaps Requiring Further Research

1. **Exact notification sequence** when menu bar auto-hides (which fires first, timing)
2. **SwiftUI MenuBarExtra implementation details** - does it handle auto-hide differently than NSStatusItem?
3. **Current app's specific implementation** - which approach is it using?
4. **macOS Sequoia (15.0+) changes** - any new APIs or behavior changes for menubar apps?
