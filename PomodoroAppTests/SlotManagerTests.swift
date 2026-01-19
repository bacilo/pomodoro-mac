import XCTest
@testable import PomodoroApp

final class SlotManagerTests: XCTestCase {
    var slotManager: SlotManager!

    override func setUp() {
        super.setUp()
        // Clear all slot-related UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: "pomodoroSlots")
        UserDefaults.standard.removeObject(forKey: "pomodoroSlotsHistory")
        UserDefaults.standard.removeObject(forKey: "defaultSlotCount")
        UserDefaults.standard.removeObject(forKey: "defaultSlotNames")
        slotManager = SlotManager()
    }

    override func tearDown() {
        slotManager = nil
        UserDefaults.standard.removeObject(forKey: "pomodoroSlots")
        UserDefaults.standard.removeObject(forKey: "pomodoroSlotsHistory")
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

    func testAddSlot_EmptyName_UsesDefault() {
        slotManager.addSlot()
        let lastSlot = slotManager.today.slots.last!
        XCTAssertTrue(lastSlot.name.starts(with: "Slot"))
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
        XCTAssertEqual(slotManager.history[0].slots[0].name, "Yesterday Task")
        XCTAssertEqual(slotManager.history[0].completedCount, 1)
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
