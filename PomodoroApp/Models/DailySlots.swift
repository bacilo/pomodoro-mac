import Foundation

/// Represents the current day's slot configuration
struct DailySlots: Codable, Equatable {
    let dateString: String
    var slots: [Slot]           // All slots for today (completed + incomplete)
    var completedCount: Int     // How many from the start are completed

    init(date: Date = Date(), slots: [Slot] = [], completedCount: Int = 0) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        self.dateString = formatter.string(from: date)
        self.slots = slots
        self.completedCount = completedCount
    }

    init(dateString: String, slots: [Slot], completedCount: Int) {
        self.dateString = dateString
        self.slots = slots
        self.completedCount = completedCount
    }

    static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }

    /// Returns only the completed slots (first `completedCount` slots)
    var completedSlots: [Slot] {
        Array(slots.prefix(completedCount))
    }

    /// Returns the names of completed slots
    var completedSlotNames: [String] {
        completedSlots.map { $0.name }
    }
}

/// Represents a day's completed slot history (just the names)
struct DayHistory: Codable, Identifiable, Equatable {
    var id: String { dateString }
    let dateString: String
    var completedSlotNames: [String]

    init(dateString: String, completedSlotNames: [String]) {
        self.dateString = dateString
        self.completedSlotNames = completedSlotNames
    }

    init(date: Date, completedSlotNames: [String]) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        self.dateString = formatter.string(from: date)
        self.completedSlotNames = completedSlotNames
    }
}
