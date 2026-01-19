import Foundation

struct DailySlots: Codable, Identifiable, Equatable {
    var id: String { dateString }
    let dateString: String
    var slots: [Slot]
    var completedCount: Int

    init(date: Date = Date(), slots: [Slot] = [], completedCount: Int = 0) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
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
        return formatter.string(from: Date())
    }
}
