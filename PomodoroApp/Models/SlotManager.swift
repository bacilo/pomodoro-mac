import Foundation
import SwiftUI

class SlotManager: ObservableObject {
    @Published var today: DailySlots
    @Published var history: [DayHistory] = []  // Only completed slot names per day

    // Default template settings
    @AppStorage("defaultSlotCount") var defaultSlotCount: Int = 12
    @Published var defaultSlotNames: [String] = []

    private let todaySlotsKey = "pomodoroSlots"
    private let historyKey = "pomodoroSlotsHistory_v2"  // New key for new format
    private let defaultNamesKey = "defaultSlotNames"

    init() {
        // Initialize with empty today, then load
        self.today = DailySlots()
        load()
        checkForNewDay()
    }

    // MARK: - Computed Properties

    var totalSlots: Int { today.slots.count }

    var hasIncompleteSlots: Bool { today.completedCount < today.slots.count }

    var nextIncompleteIndex: Int? {
        guard today.completedCount < today.slots.count else { return nil }
        return today.completedCount
    }

    var currentSlotName: String? {
        guard let index = nextIncompleteIndex else { return nil }
        return today.slots[index].name
    }

    /// Today's history entry (completed slot names)
    var todayHistory: DayHistory {
        DayHistory(dateString: today.dateString, completedSlotNames: today.completedSlotNames)
    }

    func isCompleted(at index: Int) -> Bool {
        index < today.completedCount
    }

    // MARK: - Slot Actions

    func addSlot(name: String = "") {
        let slot = Slot(name: name)
        today.slots.append(slot)
        save()
    }

    func removeSlot(at index: Int) {
        guard index >= 0 && index < today.slots.count else { return }
        today.slots.remove(at: index)
        // Adjust completedCount if we removed a completed slot
        if index < today.completedCount {
            today.completedCount = max(0, today.completedCount - 1)
        }
        save()
    }

    func renameSlot(at index: Int, to newName: String) {
        guard index >= 0 && index < today.slots.count else { return }
        today.slots[index].name = newName
        save()
        // History for today auto-syncs via todayHistory computed property
    }

    func moveSlot(from source: IndexSet, to destination: Int) {
        today.slots.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func advanceCompletion() {
        guard today.completedCount < today.slots.count else { return }
        today.completedCount += 1
        save()
    }

    func resetCompletions() {
        today.completedCount = 0
        save()
    }

    /// Mark a specific slot as incomplete (used when deleting from history)
    func markSlotIncomplete(at index: Int) {
        guard index >= 0 && index < today.completedCount else { return }
        // Move this slot to the end of the list and decrement completedCount
        let slot = today.slots.remove(at: index)
        today.slots.append(slot)
        today.completedCount -= 1
        save()
    }

    func setTodaySlotCount(_ count: Int) {
        while today.slots.count < count {
            let slotName = "Slot \(today.slots.count + 1)"
            today.slots.append(Slot(name: slotName))
        }
        while today.slots.count > count && today.slots.count > 0 {
            today.slots.removeLast()
        }
        today.completedCount = min(today.completedCount, today.slots.count)
        save()
    }

    // MARK: - Default Template Actions

    func setDefaultSlotCount(_ count: Int) {
        defaultSlotCount = count
        // Ensure defaultSlotNames array matches new count
        while defaultSlotNames.count < count {
            defaultSlotNames.append("Slot \(defaultSlotNames.count + 1)")
        }
        while defaultSlotNames.count > count {
            defaultSlotNames.removeLast()
        }
        saveDefaultNames()
    }

    func updateDefaultTemplate(at index: Int, to name: String) {
        guard index >= 0 && index < defaultSlotNames.count else { return }
        defaultSlotNames[index] = name
        saveDefaultNames()
    }

    func initializeNewDay(force: Bool = false) {
        let todayString = DailySlots.todayDateString()

        // If not forcing and already on today, do nothing
        if !force && today.dateString == todayString {
            return
        }

        // Save current day's completed slots to history
        saveCurrentDayToHistory()

        // Create new day from templates
        var slots: [Slot] = []
        for i in 0..<defaultSlotCount {
            let name = i < defaultSlotNames.count ? defaultSlotNames[i] : "Slot \(i + 1)"
            slots.append(Slot(name: name))
        }
        today = DailySlots(date: Date(), slots: slots, completedCount: 0)
        save()
    }

    private func saveCurrentDayToHistory() {
        // Only save if there are completed slots
        guard today.completedCount > 0 else { return }

        let dayHistory = todayHistory

        // Remove any existing entry for this date
        history.removeAll { $0.dateString == today.dateString }
        history.append(dayHistory)

        // Keep last 30 days
        if history.count > 30 {
            history.removeFirst(history.count - 30)
        }
    }

    /// Returns unique placeholders found in template names (text within square brackets)
    func getTemplatePlaceholders() -> [String] {
        var placeholders: [String] = []
        let pattern = "\\[([^\\]]+)\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        for name in defaultSlotNames {
            let range = NSRange(name.startIndex..., in: name)
            let matches = regex.matches(in: name, range: range)
            for match in matches {
                if let matchRange = Range(match.range(at: 1), in: name) {
                    let placeholder = String(name[matchRange])
                    if !placeholders.contains(placeholder) {
                        placeholders.append(placeholder)
                    }
                }
            }
        }
        return placeholders
    }

    /// Returns unique unfilled placeholders in today's slot names
    func getTodayUnfilledPlaceholders() -> [String] {
        var placeholders: [String] = []
        let pattern = "\\[([^\\]]+)\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        for slot in today.slots {
            let range = NSRange(slot.name.startIndex..., in: slot.name)
            let matches = regex.matches(in: slot.name, range: range)
            for match in matches {
                if let matchRange = Range(match.range(at: 1), in: slot.name) {
                    let placeholder = String(slot.name[matchRange])
                    if !placeholders.contains(placeholder) {
                        placeholders.append(placeholder)
                    }
                }
            }
        }
        return placeholders
    }

    /// Fill placeholders in today's slots
    func fillTodayPlaceholders(_ replacements: [String: String]) {
        for i in 0..<today.slots.count {
            var name = today.slots[i].name
            for (placeholder, replacement) in replacements {
                name = name.replacingOccurrences(of: "[\(placeholder)]", with: replacement)
            }
            today.slots[i].name = name
        }
        save()
    }

    /// Apply template to today with placeholder replacements
    func applyTemplateWithReplacements(_ replacements: [String: String]) {
        // Save current day's completed slots to history
        saveCurrentDayToHistory()

        // Create new day from templates with replacements
        var slots: [Slot] = []
        for i in 0..<defaultSlotCount {
            var name = i < defaultSlotNames.count ? defaultSlotNames[i] : "Slot \(i + 1)"
            // Replace all placeholders
            for (placeholder, replacement) in replacements {
                name = name.replacingOccurrences(of: "[\(placeholder)]", with: replacement)
            }
            slots.append(Slot(name: name))
        }
        today = DailySlots(date: Date(), slots: slots, completedCount: 0)
        save()
    }

    // MARK: - History Editing (for past days)

    func renameHistorySlot(dayIndex: Int, slotIndex: Int, newName: String) {
        guard dayIndex >= 0 && dayIndex < history.count else { return }
        guard slotIndex >= 0 && slotIndex < history[dayIndex].completedSlotNames.count else { return }
        history[dayIndex].completedSlotNames[slotIndex] = newName
        save()
    }

    func removeHistorySlot(dayIndex: Int, slotIndex: Int) {
        guard dayIndex >= 0 && dayIndex < history.count else { return }
        guard slotIndex >= 0 && slotIndex < history[dayIndex].completedSlotNames.count else { return }
        history[dayIndex].completedSlotNames.remove(at: slotIndex)
        save()
    }

    func addHistorySlot(dayIndex: Int, name: String = "New Slot") {
        guard dayIndex >= 0 && dayIndex < history.count else { return }
        history[dayIndex].completedSlotNames.append(name)
        save()
    }

    func deleteHistoryDay(dayIndex: Int) {
        guard dayIndex >= 0 && dayIndex < history.count else { return }
        history.remove(at: dayIndex)
        save()
    }

    func clearAllHistory(includingToday: Bool = false) {
        history = []
        if includingToday {
            // Reset today to fresh state from template
            var slots: [Slot] = []
            for i in 0..<defaultSlotCount {
                let name = i < defaultSlotNames.count ? defaultSlotNames[i] : "Slot \(i + 1)"
                slots.append(Slot(name: name))
            }
            today = DailySlots(date: Date(), slots: slots, completedCount: 0)
        }
        save()
    }

    // MARK: - Today's History Editing (syncs with slot list)

    func renameTodayCompletedSlot(at index: Int, newName: String) {
        // Renaming a completed slot updates the slot list
        guard index >= 0 && index < today.completedCount else { return }
        today.slots[index].name = newName
        save()
    }

    func removeTodayCompletedSlot(at index: Int) {
        // Removing from today's history = marking incomplete
        markSlotIncomplete(at: index)
    }

    func addTodayCompletedSlot(name: String) {
        // Adding to today's history = adding a slot and marking it complete
        let slot = Slot(name: name)
        today.slots.insert(slot, at: today.completedCount)
        today.completedCount += 1
        save()
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()

        if let todayData = try? encoder.encode(today) {
            UserDefaults.standard.set(todayData, forKey: todaySlotsKey)
        }

        if let historyData = try? encoder.encode(history) {
            UserDefaults.standard.set(historyData, forKey: historyKey)
        }
    }

    private func saveDefaultNames() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(defaultSlotNames) {
            UserDefaults.standard.set(data, forKey: defaultNamesKey)
        }
    }

    private func load() {
        let decoder = JSONDecoder()

        // Load default names first
        if let namesData = UserDefaults.standard.data(forKey: defaultNamesKey),
           let names = try? decoder.decode([String].self, from: namesData) {
            defaultSlotNames = names
        } else {
            // Initialize default names
            defaultSlotNames = (1...defaultSlotCount).map { "Slot \($0)" }
        }

        // Load history (new format)
        if let historyData = UserDefaults.standard.data(forKey: historyKey),
           let loadedHistory = try? decoder.decode([DayHistory].self, from: historyData) {
            history = loadedHistory
        }

        // Load today's slots
        let todayString = DailySlots.todayDateString()
        if let todayData = UserDefaults.standard.data(forKey: todaySlotsKey),
           let loadedToday = try? decoder.decode(DailySlots.self, from: todayData),
           loadedToday.dateString == todayString {
            // Found valid saved state for today
            today = loadedToday
        } else {
            // No saved state for today - check if there's history for today
            if let todayHistoryEntry = history.first(where: { $0.dateString == todayString }) {
                // Restore from history: completed slots from history + remaining from template
                restoreTodayFromHistory(todayHistoryEntry)
            } else {
                // No state, no history - initialize fresh from templates
                initializeNewDay(force: true)
            }
        }
    }

    private func restoreTodayFromHistory(_ historyEntry: DayHistory) {
        var slots: [Slot] = []

        // First, add completed slots from history
        for name in historyEntry.completedSlotNames {
            slots.append(Slot(name: name))
        }
        let completedCount = slots.count

        // Then, add remaining slots from template (up to defaultSlotCount)
        let remainingCount = max(0, defaultSlotCount - completedCount)
        for i in 0..<remainingCount {
            let templateIndex = completedCount + i
            let name = templateIndex < defaultSlotNames.count ? defaultSlotNames[templateIndex] : "Slot \(templateIndex + 1)"
            slots.append(Slot(name: name))
        }

        today = DailySlots(dateString: historyEntry.dateString, slots: slots, completedCount: completedCount)
        save()
    }

    /// Checks if a new day has started and initializes the new day if needed.
    /// - Returns: `true` if a new day was detected and initialized, `false` otherwise.
    @discardableResult
    func checkForNewDay() -> Bool {
        let todayString = DailySlots.todayDateString()
        if today.dateString != todayString {
            initializeNewDay()
            return true
        }
        return false
    }
}
