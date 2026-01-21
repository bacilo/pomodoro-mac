import XCTest
@testable import PomodoroApp

final class SlotManagerTests: XCTestCase {
    var slotManager: SlotManager!

    override func setUp() {
        super.setUp()
        // Clear all slot-related UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: "pomodoroSlots")
        UserDefaults.standard.removeObject(forKey: "pomodoroSlotsHistory")
        UserDefaults.standard.removeObject(forKey: "pomodoroSlotsHistory_v2")
        UserDefaults.standard.removeObject(forKey: "defaultSlotCount")
        UserDefaults.standard.removeObject(forKey: "defaultSlotNames")
        slotManager = SlotManager()
    }

    override func tearDown() {
        slotManager = nil
        UserDefaults.standard.removeObject(forKey: "pomodoroSlots")
        UserDefaults.standard.removeObject(forKey: "pomodoroSlotsHistory")
        UserDefaults.standard.removeObject(forKey: "pomodoroSlotsHistory_v2")
        UserDefaults.standard.removeObject(forKey: "defaultSlotCount")
        UserDefaults.standard.removeObject(forKey: "defaultSlotNames")
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState_HasDefaultSlots() {
        // Default slot count is 12
        XCTAssertEqual(slotManager.today.slots.count, 12)
        XCTAssertEqual(slotManager.today.completedCount, 0)
    }

    func testInitialState_DefaultSlotNames() {
        // First slot should have default name pattern
        XCTAssertTrue(slotManager.today.slots[0].name.starts(with: "Slot"))
    }

    // MARK: - Add Slot Tests

    func testAddSlot_IncreasesCount() {
        let initialCount = slotManager.today.slots.count
        slotManager.addSlot(name: "New Task")
        XCTAssertEqual(slotManager.today.slots.count, initialCount + 1)
        XCTAssertEqual(slotManager.today.slots.last?.name, "New Task")
    }

    func testAddSlot_EmptyName_AllowsEmpty() {
        slotManager.addSlot()
        let lastSlot = slotManager.today.slots.last!
        XCTAssertEqual(lastSlot.name, "")
    }

    // MARK: - Remove Slot Tests

    func testRemoveSlot_DecreasesCount() {
        let initialCount = slotManager.today.slots.count
        slotManager.removeSlot(at: 0)
        XCTAssertEqual(slotManager.today.slots.count, initialCount - 1)
    }

    func testRemoveSlot_AdjustsCompletedCount_WhenRemovingCompleted() {
        slotManager.advanceCompletion()
        slotManager.advanceCompletion()
        XCTAssertEqual(slotManager.today.completedCount, 2)

        slotManager.removeSlot(at: 0) // Remove a completed slot
        XCTAssertEqual(slotManager.today.completedCount, 1)
    }

    func testRemoveSlot_DoesNotAdjustCompletedCount_WhenRemovingIncomplete() {
        slotManager.advanceCompletion()
        XCTAssertEqual(slotManager.today.completedCount, 1)

        slotManager.removeSlot(at: 5) // Remove an incomplete slot
        XCTAssertEqual(slotManager.today.completedCount, 1)
    }

    func testRemoveSlot_InvalidIndex_DoesNothing() {
        let initialCount = slotManager.today.slots.count
        slotManager.removeSlot(at: 100)
        XCTAssertEqual(slotManager.today.slots.count, initialCount)
    }

    // MARK: - Rename Tests

    func testRenameSlot_UpdatesName() {
        slotManager.renameSlot(at: 0, to: "Updated Name")
        XCTAssertEqual(slotManager.today.slots[0].name, "Updated Name")
    }

    func testRenameSlot_InvalidIndex_DoesNothing() {
        let originalName = slotManager.today.slots[0].name
        slotManager.renameSlot(at: 100, to: "New Name")
        XCTAssertEqual(slotManager.today.slots[0].name, originalName)
    }

    // MARK: - Move/Reorder Tests

    func testMoveSlot_ReordersArray() {
        // Set up named slots
        slotManager.renameSlot(at: 0, to: "A")
        slotManager.renameSlot(at: 1, to: "B")
        slotManager.renameSlot(at: 2, to: "C")

        slotManager.moveSlot(from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(slotManager.today.slots[0].name, "C")
        XCTAssertEqual(slotManager.today.slots[1].name, "A")
        XCTAssertEqual(slotManager.today.slots[2].name, "B")
    }

    func testMoveSlot_CompletedCountUnchanged() {
        slotManager.advanceCompletion()
        slotManager.advanceCompletion()

        slotManager.moveSlot(from: IndexSet(integer: 5), to: 0)

        // Completed count should stay the same
        XCTAssertEqual(slotManager.today.completedCount, 2)
        // First two slots should still be completed
        XCTAssertTrue(slotManager.isCompleted(at: 0))
        XCTAssertTrue(slotManager.isCompleted(at: 1))
        XCTAssertFalse(slotManager.isCompleted(at: 2))
    }

    // MARK: - Completion Tests

    func testAdvanceCompletion_IncrementsCount() {
        slotManager.advanceCompletion()

        XCTAssertEqual(slotManager.today.completedCount, 1)
        XCTAssertTrue(slotManager.isCompleted(at: 0))
        XCTAssertFalse(slotManager.isCompleted(at: 1))
    }

    func testAdvanceCompletion_StopsAtMax() {
        // Complete all slots
        for _ in 0..<slotManager.today.slots.count {
            slotManager.advanceCompletion()
        }
        let maxCount = slotManager.today.completedCount

        // Try to advance beyond max
        slotManager.advanceCompletion()

        XCTAssertEqual(slotManager.today.completedCount, maxCount)
    }

    func testResetCompletions_SetsToZero() {
        slotManager.advanceCompletion()
        slotManager.advanceCompletion()
        slotManager.resetCompletions()

        XCTAssertEqual(slotManager.today.completedCount, 0)
    }

    // MARK: - Computed Property Tests

    func testHasIncompleteSlots() {
        XCTAssertTrue(slotManager.hasIncompleteSlots)

        // Complete all slots
        for _ in 0..<slotManager.today.slots.count {
            slotManager.advanceCompletion()
        }
        XCTAssertFalse(slotManager.hasIncompleteSlots)
    }

    func testNextIncompleteIndex() {
        XCTAssertEqual(slotManager.nextIncompleteIndex, 0)

        slotManager.advanceCompletion()
        XCTAssertEqual(slotManager.nextIncompleteIndex, 1)

        slotManager.advanceCompletion()
        XCTAssertEqual(slotManager.nextIncompleteIndex, 2)

        // Complete all
        for _ in 0..<slotManager.today.slots.count {
            slotManager.advanceCompletion()
        }
        XCTAssertNil(slotManager.nextIncompleteIndex)
    }

    func testTotalSlots() {
        XCTAssertEqual(slotManager.totalSlots, 12)

        slotManager.addSlot()
        XCTAssertEqual(slotManager.totalSlots, 13)
    }

    // MARK: - Persistence Tests

    func testPersistence_TodaySlots() {
        slotManager.renameSlot(at: 0, to: "Persisted Task")
        slotManager.advanceCompletion()

        let newManager = SlotManager()

        XCTAssertEqual(newManager.today.slots[0].name, "Persisted Task")
        XCTAssertEqual(newManager.today.completedCount, 1)
    }

    // MARK: - Default Template Tests

    func testSetDefaultSlotCount() {
        slotManager.setDefaultSlotCount(8)
        XCTAssertEqual(slotManager.defaultSlotCount, 8)
    }

    func testUpdateDefaultTemplate() {
        slotManager.updateDefaultTemplate(at: 0, to: "Morning Emails")
        XCTAssertEqual(slotManager.defaultSlotNames[0], "Morning Emails")
    }

    func testDefaultTemplates_ApplyToNewDay() {
        // Set up templates
        slotManager.setDefaultSlotCount(3)
        slotManager.updateDefaultTemplate(at: 0, to: "Task A")
        slotManager.updateDefaultTemplate(at: 1, to: "Task B")
        slotManager.updateDefaultTemplate(at: 2, to: "Task C")

        // Force a new day initialization
        slotManager.initializeNewDay(force: true)

        XCTAssertEqual(slotManager.today.slots.count, 3)
        XCTAssertEqual(slotManager.today.slots[0].name, "Task A")
        XCTAssertEqual(slotManager.today.slots[1].name, "Task B")
        XCTAssertEqual(slotManager.today.slots[2].name, "Task C")
        XCTAssertEqual(slotManager.today.completedCount, 0)
    }

    // MARK: - History Tests

    func testHistory_SavesWhenNewDayStarts() {
        slotManager.renameSlot(at: 0, to: "Yesterday Task")
        slotManager.advanceCompletion()

        // Force new day (simulates day change)
        slotManager.initializeNewDay(force: true)

        XCTAssertEqual(slotManager.history.count, 1)
        XCTAssertEqual(slotManager.history[0].completedSlotNames.count, 1)
        XCTAssertEqual(slotManager.history[0].completedSlotNames[0], "Yesterday Task")
    }

    func testHistory_OnlyStoresCompletedSlots() {
        slotManager.renameSlot(at: 0, to: "Task A")
        slotManager.renameSlot(at: 1, to: "Task B")
        slotManager.renameSlot(at: 2, to: "Task C")
        slotManager.advanceCompletion() // Complete Task A
        slotManager.advanceCompletion() // Complete Task B
        // Task C remains incomplete

        slotManager.initializeNewDay(force: true)

        XCTAssertEqual(slotManager.history[0].completedSlotNames.count, 2)
        XCTAssertEqual(slotManager.history[0].completedSlotNames[0], "Task A")
        XCTAssertEqual(slotManager.history[0].completedSlotNames[1], "Task B")
    }

    // MARK: - Today's History Editing Tests (Bidirectional Sync)

    func testRenameTodayCompletedSlot_UpdatesSlotList() {
        slotManager.renameSlot(at: 0, to: "Original Name")
        slotManager.advanceCompletion()

        slotManager.renameTodayCompletedSlot(at: 0, newName: "New Name")

        XCTAssertEqual(slotManager.today.slots[0].name, "New Name")
    }

    func testRemoveTodayCompletedSlot_MarksIncomplete() {
        slotManager.advanceCompletion()
        slotManager.advanceCompletion()
        XCTAssertEqual(slotManager.today.completedCount, 2)

        slotManager.removeTodayCompletedSlot(at: 0)

        XCTAssertEqual(slotManager.today.completedCount, 1)
        // The removed slot should now be at the end
        XCTAssertEqual(slotManager.today.slots.count, 12)
    }

    func testAddTodayCompletedSlot_InsertsAtCompletedPosition() {
        slotManager.advanceCompletion() // 1 completed
        let initialCount = slotManager.today.slots.count

        slotManager.addTodayCompletedSlot(name: "New Completed Task")

        XCTAssertEqual(slotManager.today.completedCount, 2)
        XCTAssertEqual(slotManager.today.slots.count, initialCount + 1)
        XCTAssertEqual(slotManager.today.slots[1].name, "New Completed Task")
    }

    func testMarkSlotIncomplete_MovesToEnd() {
        slotManager.renameSlot(at: 0, to: "Task A")
        slotManager.renameSlot(at: 1, to: "Task B")
        slotManager.advanceCompletion()
        slotManager.advanceCompletion()

        slotManager.markSlotIncomplete(at: 0)

        XCTAssertEqual(slotManager.today.completedCount, 1)
        XCTAssertEqual(slotManager.today.slots[0].name, "Task B")
        XCTAssertEqual(slotManager.today.slots.last?.name, "Task A")
    }

    // MARK: - History Day Editing Tests

    func testRenameHistorySlot() {
        slotManager.advanceCompletion()
        slotManager.initializeNewDay(force: true)

        slotManager.renameHistorySlot(dayIndex: 0, slotIndex: 0, newName: "Renamed")

        XCTAssertEqual(slotManager.history[0].completedSlotNames[0], "Renamed")
    }

    func testRemoveHistorySlot() {
        slotManager.advanceCompletion()
        slotManager.advanceCompletion()
        slotManager.initializeNewDay(force: true)

        slotManager.removeHistorySlot(dayIndex: 0, slotIndex: 0)

        XCTAssertEqual(slotManager.history[0].completedSlotNames.count, 1)
    }

    func testAddHistorySlot() {
        slotManager.advanceCompletion()
        slotManager.initializeNewDay(force: true)

        slotManager.addHistorySlot(dayIndex: 0, name: "Added Task")

        XCTAssertEqual(slotManager.history[0].completedSlotNames.count, 2)
        XCTAssertEqual(slotManager.history[0].completedSlotNames[1], "Added Task")
    }

    func testDeleteHistoryDay() {
        slotManager.advanceCompletion()
        slotManager.initializeNewDay(force: true)

        XCTAssertEqual(slotManager.history.count, 1)

        slotManager.deleteHistoryDay(dayIndex: 0)

        XCTAssertEqual(slotManager.history.count, 0)
    }

    // MARK: - Check For New Day Tests

    func testCheckForNewDay_ReturnsFalse_WhenSameDay() {
        // When it's still the same day, checkForNewDay should return false
        let result = slotManager.checkForNewDay()
        XCTAssertFalse(result)
    }

    func testCheckForNewDay_ReturnsTrue_WhenDateChanges() {
        // Simulate date change by manually setting today to a past date
        // First, complete some work so we can verify history was saved
        slotManager.renameSlot(at: 0, to: "Yesterday Work")
        slotManager.advanceCompletion()

        // Manually create a past day state by modifying today directly
        // We'll use the fact that DailySlots can be created with a custom dateString
        let yesterdayString = "2020-01-01"  // A date in the past
        slotManager.today = DailySlots(dateString: yesterdayString, slots: slotManager.today.slots, completedCount: slotManager.today.completedCount)

        // Now checkForNewDay should detect the mismatch and return true
        let result = slotManager.checkForNewDay()
        XCTAssertTrue(result)

        // Verify new day was initialized
        XCTAssertEqual(slotManager.today.completedCount, 0)
        XCTAssertNotEqual(slotManager.today.dateString, yesterdayString)
    }

    func testCheckForNewDay_SavesHistory_WhenDateChanges() {
        slotManager.renameSlot(at: 0, to: "Task From Old Day")
        slotManager.advanceCompletion()

        // Simulate a past date
        let pastDateString = "2020-01-01"
        slotManager.today = DailySlots(dateString: pastDateString, slots: slotManager.today.slots, completedCount: slotManager.today.completedCount)

        let initialHistoryCount = slotManager.history.count

        _ = slotManager.checkForNewDay()

        // History should have been saved
        XCTAssertEqual(slotManager.history.count, initialHistoryCount + 1)
        XCTAssertEqual(slotManager.history.last?.completedSlotNames.first, "Task From Old Day")
    }

    // MARK: - Set Slot Count Tests

    func testSetTodaySlotCount_AddsSlots() {
        let initialCount = slotManager.today.slots.count
        slotManager.setTodaySlotCount(initialCount + 3)
        XCTAssertEqual(slotManager.today.slots.count, initialCount + 3)
    }

    func testSetTodaySlotCount_RemovesSlots() {
        slotManager.setTodaySlotCount(5)
        XCTAssertEqual(slotManager.today.slots.count, 5)
    }

    func testSetTodaySlotCount_AdjustsCompletedCount() {
        slotManager.advanceCompletion()
        slotManager.advanceCompletion()
        slotManager.advanceCompletion()
        slotManager.advanceCompletion()
        slotManager.advanceCompletion() // 5 completed

        slotManager.setTodaySlotCount(3)

        XCTAssertEqual(slotManager.today.completedCount, 3)
    }
}
