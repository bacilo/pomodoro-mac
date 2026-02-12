# Codebase Concerns

**Analysis Date:** 2026-02-12

## Tech Debt

**AppDelegate Timer Management (Blink & Marquee Timers):**
- Issue: Multiple Timer instances managed at AppDelegate level with manual invalidation. Timers can accumulate if state transitions are rapid.
- Files: `PomodoroApp.swift` (lines 32, 116-127, 143-156)
- Impact: Potential memory leak if timers aren't properly invalidated during state transitions. Risk of multiple timers firing simultaneously under edge cases.
- Fix approach: Implement a centralized timer pool or use Combine scheduling with cancellables instead of raw Timer objects. Replace `blinkTimer` and `marqueeTimer` with Combine-based subscriptions.

**Complex State Machine in SlotManager:**
- Issue: SlotManager has 395 lines managing multiple concerns: daily slots, history, templates, placeholders, and persistence. Logic for new day detection, placeholder filling, and history syncing is intertwined.
- Files: `Models/SlotManager.swift` (entire file)
- Impact: Difficult to modify history logic without affecting slot completion. Placeholder replacement logic duplicated in `fillTodayPlaceholders()` and `applyTemplateWithReplacements()`.
- Fix approach: Extract template application into separate service. Create dedicated StateMachine for new day detection. Separate history management from slot management into distinct classes.

**DateFormatter Created in Multiple Locations:**
- Issue: DateFormatter instantiation duplicated across `DailySlots.swift`, `Statistics.swift`, and `SlotManager.swift`. Each creates formatter with "yyyy-MM-dd" format independently.
- Files: `Models/DailySlots.swift` (line 10), `Models/Statistics.swift` (lines 37, 49, 61), `Models/SlotManager.swift` (line 110, 151, 175)
- Impact: Inconsistent date formatting if format changes. Performance cost of repeated formatter initialization.
- Fix approach: Create shared `DateFormatter` utility or extend `Date` with computed property for date string. Use centralized constant for date format string.

**UserDefaults Keys Scattered and Inconsistent:**
- Issue: Storage keys defined locally in each class without centralization. SlotManager uses both `"pomodoroSlotsHistory"` (old) and `"pomodoroSlotsHistory_v2"` (new) keys.
- Files: `Models/SlotManager.swift` (lines 12-14), `Models/Statistics.swift` (lines 22-23), `Models/Settings.swift` (@AppStorage), `Views/PomodoroApp.swift`
- Impact: Hard to track all persisted data. Migration logic split across multiple files. Risk of key collisions.
- Fix approach: Create `PersistenceKeys` enum with all keys centralized. Consolidate migration logic in single location.

**Notification Request Identifier Generation:**
- Issue: UNNotificationRequest uses UUID().uuidString for each notification, creating unique identifiers that prevent proper deduplication.
- Files: `ViewModels/PomodoroViewModel.swift` (line 243)
- Impact: Multiple notifications may queue for same event if sent rapidly. Notifications don't replace previous ones; they stack.
- Fix approach: Use deterministic identifier based on timer state (e.g., "completion.\(timerState.rawValue)") to allow notification replacement.

## Known Bugs

**Marquee Display Potential Index Out of Bounds:**
- Symptoms: If slot name changes during marquee animation, character indexing could fail.
- Files: `PomodoroApp.swift` (lines 224-236)
- Trigger: Rename slot while marquee is active, rapid slot name changes, or if marqueeOffset exceeds string bounds.
- Current protection: String wrapping in the loop, but index calculation assumes consistent string length.
- Workaround: The code guards against endIndex by resetting to startIndex, but race conditions between state updates are possible.

**Placeholder Prompt Can Show Wrong Index on Cancel/Reopen:**
- Symptoms: If user cancels placeholder prompt and reopens, `currentPlaceholderIndex` not properly reset in all cases.
- Files: `Views/SlotTemplatesView.swift` (lines 156-163)
- Trigger: Open template dialog → apply templates → fill first placeholder → cancel → reopen → apply templates again
- Current protection: `cancelPlaceholderPrompt()` resets fields, but view state between close and reopen may not synchronize properly.
- Workaround: Force dismiss and reopen the view completely to clear state.

**Session Start Time Loss on Quick State Transitions:**
- Symptoms: If user rapid-fires "completeEarly" followed by skip/state change, `sessionStartTime` could be `nil` during recording.
- Files: `ViewModels/PomodoroViewModel.swift` (lines 193-213)
- Trigger: Complete early → immediately skip → start new session before UI updates
- Current protection: `guard let startTime = sessionStartTime else { return }` prevents crash but silently loses session data.
- Impact: Some work sessions won't be recorded in statistics if transitions happen quickly.

## Security Considerations

**No Validation of Custom Slot Names:**
- Risk: Slot names from user input are not validated for length or special characters before storage or display.
- Files: `Models/SlotManager.swift` (lines 66-71, 125-129), `Views/SlotsView.swift`, `Views/HistoryView.swift`
- Current mitigation: SwiftUI TextField max length enforced at UI layer only. No database-layer validation.
- Recommendations: Add max length constant (e.g., 100 chars). Strip leading/trailing whitespace on save. Validate placeholder names in templates.

**Clipboard Access via Drag/Drop:**
- Risk: `NSItemProvider` used for drag operations could expose internal UUIDs if intercepted.
- Files: `Views/SlotsView.swift` (line 64)
- Current mitigation: Only exposes UUID string which is non-sensitive.
- Recommendations: Not a significant risk but monitor for future data types exposed via drag/drop.

**No Data Encryption for Persisted Statistics:**
- Risk: All user statistics, session times, and slot names stored in plaintext via UserDefaults.
- Files: `Models/Statistics.swift` (lines 127-134), `Models/SlotManager.swift` (lines 307-317)
- Current mitigation: UserDefaults on macOS stores data in plaintext plist. User's login protects the file.
- Recommendations: For high-privacy use case, consider Keychain storage for statistics or at-rest encryption.

## Performance Bottlenecks

**DateFormatter Allocation in Loop:**
- Problem: `Statistics.last7Days` creates new DateFormatter on every call (lines 59-61).
- Files: `Models/Statistics.swift` (lines 58-74)
- Cause: Formatter recreated each time property is accessed, even if called multiple times per render cycle.
- Current impact: Minor for daily use, but visible if StatsView refreshes frequently.
- Improvement path: Cache formatter as class-level property or use single static instance.

**String Manipulation in Marquee Animation:**
- Problem: `fullText = slotName + marqueePadding` and substring extraction happens on every timer tick.
- Files: `PomodoroApp.swift` (lines 144-149, 224-236)
- Cause: String concatenation and index manipulation every 0.3 seconds.
- Current impact: Negligible for modern hardware, but technically wasteful.
- Improvement path: Pre-compute marquee string once when slot name changes, not on every animation frame.

**Linear Search for Slot by Index on Every Drag Operation:**
- Problem: SlotDropDelegate must search for slot index, and slotManager array is searched multiple times per drop.
- Files: `Views/SlotsView.swift` (line 66-70), `Models/SlotManager.swift` (lines 73-76)
- Cause: Moving slots requires full array reconstruction via IndexSet operations.
- Impact: Performance degrades as slot count increases beyond 30+.
- Improvement path: Index-based operations already used; no major change needed unless slot counts exceed 100.

**Persistence Write on Every Slot Change:**
- Problem: `SlotManager.save()` writes entire slot array and history to UserDefaults on each modification.
- Files: `Models/SlotManager.swift` (lines 307-317, called after every state mutation)
- Cause: No batch operations or write debouncing. Each slot rename, add, or move triggers a disk write.
- Impact: With templates feature, users can have 30+ slots. Each operation is a full serialize/write.
- Improvement path: Implement write debouncing (e.g., 500ms timer) or batch operations when bulk-modifying slots.

## Fragile Areas

**SlotManager History Editing Logic:**
- Files: `Models/SlotManager.swift` (lines 243-303)
- Why fragile: When editing history, `renameHistorySlot()`, `removeHistorySlot()`, and `addHistorySlot()` directly mutate past day data. No validation that dates align with actual completion times. Statistics can become out of sync if history is modified without updating `Statistics.dailyStats`.
- Safe modification: Always update both `slotManager.history` and `statistics.dailyStats` together. Test that editing past day history updates statistics view. Consider adding invariant checks.
- Test coverage: `SlotManagerTests` has limited history editing tests. Missing edge cases for deleting days and syncing with statistics.

**Placeholder Filling State Machine:**
- Files: `Views/SlotTemplatesView.swift` (lines 10-16, 122-163)
- Why fragile: Multiple state variables (`currentPlaceholderIndex`, `placeholdersToFill`, `placeholderReplacements`) must stay in sync. If any are inconsistent, placeholder flow breaks. Array index bounds not explicitly checked before access (line 152).
- Safe modification: Extract into dedicated PlaceholderFiller class with single source of truth. Validate array bounds before indexing. Add comprehensive tests for placeholder flow (happy path, cancel, reopen).
- Test coverage: No tests exist for placeholder functionality. This is completely untested.

**AppDelegate Timer Cancellation Timing:**
- Files: `PomodoroApp.swift` (lines 116-127, 143-156)
- Why fragile: Timers invalidated when state no longer requires them, but rapid state changes can create race conditions. If `updateStatusButton()` is called multiple times per second (possible during timer tick), timers might be created/destroyed excessively.
- Safe modification: Consolidate timer setup into single method. Use guard statements to prevent redundant creation. Add explicit lifecycle management (created when needed, held while needed, invalidated once).
- Test coverage: No unit tests for AppDelegate timer management. UI tests would be needed.

**Slot Index Assumptions:**
- Files: `Models/SlotManager.swift` (line 31 assumes `completedCount` equals first N slots), `Views/SlotsView.swift` (line 51 assumes first N are completed)
- Why fragile: Code assumes completed slots are always the first N slots in the array. If a slot is removed from the middle of completed slots, this assumption breaks. `markSlotIncomplete()` works around this by moving slot to end, but it's implicit.
- Safe modification: Add explicit invariant check: completed slots are always first `completedCount` elements. Add test for this invariant.
- Test coverage: Slot manager tests cover basic operations but don't stress-test the ordering assumption with complex sequences.

## Scaling Limits

**History Array Limited to 30 Days:**
- Current capacity: Fixed at 30 days (line 163 in SlotManager)
- Limit: Users with long-running apps will lose history older than 30 days. If app runs for 1+ years, 90% of history is discarded.
- Scaling path: Store history in a database (SQLite) or implement configurable retention. Consider cloud backup for long-term analytics.

**Session Array Limited to 1000 Records:**
- Current capacity: Last 1000 timer sessions stored (line 92 in Statistics)
- Limit: With sessions created for work, breaks, and skips, 1000 records = ~2-3 days of detailed activity at default settings.
- Scaling path: Use date-based cleanup instead of fixed count. Archive old sessions or implement tiered storage (recent in memory, old in database).

**UI Performance with Many Slots:**
- Current capacity: No hard limit, but testing done with 12 slots
- Limit: ForEach in SlotsView (line 46) renders all slots. With 50+ slots, scroll performance degrades.
- Scaling path: Implement lazy loading or paginated view. Profile with 100+ slots.

**Memory Usage for Marquee Text:**
- Current capacity: Slot names limited by SwiftUI TextField max length (UI constraint)
- Limit: If slot names approach 1000+ characters, marquee animation string concatenation becomes wasteful
- Scaling path: Cap slot name length at 200 characters. Pre-validate input.

## Dependencies at Risk

**DateFormatter Deprecation:**
- Risk: DateFormatter is legacy API. Apple encourages Date.ISO8601FormatStyle for new code.
- Impact: Code compiles but uses older patterns. May become deprecated in future macOS versions.
- Migration plan: Replace DateFormatter with `Date.FormatStyle` (available in macOS 12+) or ISO8601FormatStyle.

**UserDefaults Stability:**
- Risk: UserDefaults is not a database. Not designed for complex data structures or large storage.
- Impact: Current usage (statistics, sessions, slots) works but could become problematic if schema evolves.
- Migration plan: Consider CoreData or SQLite for persistence layer once feature set stabilizes.

**System Sound API Stability:**
- Risk: `NSSound` is legacy AppKit API. No Swift-native replacement available yet.
- Impact: Sound playback works but relies on deprecated API.
- Migration plan: Monitor Apple's announcements for modern audio APIs. Current approach is acceptable.

## Missing Critical Features

**No Undo/Redo for Slot Modifications:**
- Problem: Users can't undo slot deletions or renames. Lost data is permanent.
- Blocks: Cannot safely allow users to bulk-edit slots or apply templates if mistakes are permanent.
- Impact: Users avoid using template feature for fear of data loss.
- Priority: Medium

**No Conflict Resolution for Multi-Session Overlaps:**
- Problem: If user imports/syncs from another device, no handling for timeline conflicts.
- Blocks: Cannot implement cloud sync or multi-device support without this.
- Impact: Future feature is blocked. Currently single-device only by design.
- Priority: Low (not in current scope)

**No Session Pause/Resume Across Timer States:**
- Problem: If user pauses in work state and comes back after 1 week, session is lost.
- Blocks: Cannot implement "continue session" feature for multi-day work.
- Impact: Long-running tasks can't be tracked across application restarts.
- Priority: Low (acceptable for current design)

## Test Coverage Gaps

**AppDelegate Not Unit-Tested:**
- What's not tested: Entire AppDelegate.swift is excluded from tests (no test file exists).
- Files: `PomodoroApp.swift` (337 lines, 0% coverage)
- Risk: Timer management, menubar button updates, popover state, and context menu logic have zero test coverage.
- Priority: High - AppDelegate is critical UI component

**Placeholder Functionality Not Tested:**
- What's not tested: No tests for placeholder detection, filling, or template application.
- Files: `Views/SlotTemplatesView.swift`, `Models/SlotManager.swift` (methods `getTemplatePlaceholders`, `fillTodayPlaceholders`, `applyTemplateWithReplacements`)
- Risk: Placeholder flow is complex state machine with zero coverage.
- Priority: High - Feature was recently added

**View Unit Tests Missing:**
- What's not tested: No unit tests for any SwiftUI views (SettingsView, StatsView, HistoryView, TimerView, SlotsView).
- Files: `PomodoroApp/Views/` (all files)
- Risk: UI logic like settings persistence, stats calculations in views not verified.
- Priority: Medium - Can be caught by manual testing

**AppDelegate-ViewModel Integration:**
- What's not tested: NotificationCenter subscriptions, menubar item creation, popover lifecycle.
- Files: `PomodoroApp.swift` (lines 46-108)
- Risk: Integration between AppDelegate and PomodoroViewModel can break silently.
- Priority: High - Critical for app functionality

**Concurrency and Race Conditions:**
- What's not tested: No stress tests for rapid state transitions, concurrent operations, or timer edge cases.
- Files: `ViewModels/PomodoroViewModel.swift` (timer logic), `Models/SlotManager.swift` (state mutations)
- Risk: Edge cases with rapid timer completions, slot renames during completion, or state transitions not covered.
- Priority: Medium

---

*Concerns audit: 2026-02-12*
