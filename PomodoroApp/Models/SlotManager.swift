import Foundation
import SwiftUI

class SlotManager: ObservableObject {
    @Published var today: DailySlots
    @Published var history: [DailySlots] = []

    // Default template settings
    @AppStorage("defaultSlotCount") var defaultSlotCount: Int = 12
    @Published var defaultSlotNames: [String] = []

    private let todaySlotsKey = "pomodoroSlots"
    private let historyKey = "pomodoroSlotsHistory"
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

    func isCompleted(at index: Int) -> Bool {
        index < today.completedCount
    }

    // MARK: - Slot Actions

    func addSlot(name: String = "") {
        let slotName = name.isEmpty ? "Slot \(today.slots.count + 1)" : name
        let slot = Slot(name: slotName)
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

        // Save current day to history if it has data
        if !today.slots.isEmpty {
            // Remove any existing entry for this date to avoid duplicates
            history.removeAll { $0.dateString == today.dateString }
            history.append(today)
            // Keep last 30 days of history
            if history.count > 30 {
                history.removeFirst(history.count - 30)
            }
        }

        // Create new day from templates
        var slots: [Slot] = []
        for i in 0..<defaultSlotCount {
            let name = i < defaultSlotNames.count ? defaultSlotNames[i] : "Slot \(i + 1)"
            slots.append(Slot(name: name))
        }
        today = DailySlots(date: Date(), slots: slots, completedCount: 0)
        save()
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

    /// Apply template to today with placeholder replacements
    func applyTemplateWithReplacements(_ replacements: [String: String]) {
        let todayString = DailySlots.todayDateString()

        // Save current day to history if it has data
        if !today.slots.isEmpty {
            history.removeAll { $0.dateString == today.dateString }
            history.append(today)
            if history.count > 30 {
                history.removeFirst(history.count - 30)
            }
        }

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

    // MARK: - History Editing

    func updateHistorySlot(dayIndex: Int, slotIndex: Int, newName: String) {
        guard dayIndex >= 0 && dayIndex < history.count else { return }
        guard slotIndex >= 0 && slotIndex < history[dayIndex].slots.count else { return }
        history[dayIndex].slots[slotIndex].name = newName
        save()
    }

    func removeHistorySlot(dayIndex: Int, slotIndex: Int) {
        guard dayIndex >= 0 && dayIndex < history.count else { return }
        guard slotIndex >= 0 && slotIndex < history[dayIndex].slots.count else { return }
        history[dayIndex].slots.remove(at: slotIndex)
        // Adjust completedCount if we removed a completed slot
        if slotIndex < history[dayIndex].completedCount {
            history[dayIndex].completedCount = max(0, history[dayIndex].completedCount - 1)
        }
        save()
    }

    func addHistorySlot(dayIndex: Int, name: String = "New Slot") {
        guard dayIndex >= 0 && dayIndex < history.count else { return }
        history[dayIndex].slots.append(Slot(name: name))
        save()
    }

    func setHistoryCompletedCount(dayIndex: Int, count: Int) {
        guard dayIndex >= 0 && dayIndex < history.count else { return }
        let maxCount = history[dayIndex].slots.count
        history[dayIndex].completedCount = max(0, min(count, maxCount))
        save()
    }

    func deleteHistoryDay(dayIndex: Int) {
        guard dayIndex >= 0 && dayIndex < history.count else { return }
        history.remove(at: dayIndex)
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

        // Load history
        if let historyData = UserDefaults.standard.data(forKey: historyKey),
           let loadedHistory = try? decoder.decode([DailySlots].self, from: historyData) {
            history = loadedHistory
        }

        // Load today's slots
        if let todayData = UserDefaults.standard.data(forKey: todaySlotsKey),
           let loadedToday = try? decoder.decode(DailySlots.self, from: todayData) {
            today = loadedToday
        } else {
            // No saved data - initialize with defaults
            initializeNewDay(force: true)
        }
    }

    private func checkForNewDay() {
        let todayString = DailySlots.todayDateString()
        if today.dateString != todayString {
            initializeNewDay()
        }
    }
}
