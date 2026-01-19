import Foundation

struct DailyStats: Codable, Identifiable {
    var id: String { dateString }
    let dateString: String
    var completedPomodoros: Int
    var totalFocusMinutes: Int

    init(date: Date = Date(), completedPomodoros: Int = 0, totalFocusMinutes: Int = 0) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.dateString = formatter.string(from: date)
        self.completedPomodoros = completedPomodoros
        self.totalFocusMinutes = totalFocusMinutes
    }
}

class Statistics: ObservableObject {
    @Published var dailyStats: [DailyStats] = []
    @Published var sessions: [TimerSession] = []

    private let storageKey = "pomodoroStatistics"
    private let sessionsKey = "pomodoroSessions"

    init() {
        load()
    }

    var todayStats: DailyStats {
        let today = DailyStats()
        return dailyStats.first { $0.dateString == today.dateString } ?? today
    }

    var weeklyPomodoros: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let weekAgoString = formatter.string(from: weekAgo)

        return dailyStats
            .filter { $0.dateString >= weekAgoString }
            .reduce(0) { $0 + $1.completedPomodoros }
    }

    var monthlyPomodoros: Int {
        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let monthAgoString = formatter.string(from: monthAgo)

        return dailyStats
            .filter { $0.dateString >= monthAgoString }
            .reduce(0) { $0 + $1.completedPomodoros }
    }

    var last7Days: [DailyStats] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var result: [DailyStats] = []
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            let dateString = formatter.string(from: date)
            if let existing = dailyStats.first(where: { $0.dateString == dateString }) {
                result.append(existing)
            } else {
                result.append(DailyStats(date: date))
            }
        }
        return result.reversed()
    }

    func recordCompletedPomodoro(durationMinutes: Int) {
        let today = DailyStats()
        if let index = dailyStats.firstIndex(where: { $0.dateString == today.dateString }) {
            dailyStats[index].completedPomodoros += 1
            dailyStats[index].totalFocusMinutes += durationMinutes
        } else {
            var newStats = today
            newStats.completedPomodoros = 1
            newStats.totalFocusMinutes = durationMinutes
            dailyStats.append(newStats)
        }
        save()
    }

    func recordSession(_ session: TimerSession) {
        sessions.append(session)
        if sessions.count > 1000 {
            sessions.removeFirst(sessions.count - 1000)
        }
        save()
    }

    func clearAll() {
        dailyStats = []
        sessions = []
        save()
    }

    /// Update the completed count for a specific day (called when history is modified)
    func updateDayCount(dateString: String, completedCount: Int) {
        if let index = dailyStats.firstIndex(where: { $0.dateString == dateString }) {
            dailyStats[index].completedPomodoros = completedCount
        } else if completedCount > 0 {
            // Create a new entry for this day
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: dateString) {
                var newStats = DailyStats(date: date)
                newStats.completedPomodoros = completedCount
                dailyStats.append(newStats)
            }
        }
        save()
    }

    /// Remove a day's stats entirely
    func removeDay(dateString: String) {
        dailyStats.removeAll { $0.dateString == dateString }
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        if let statsData = try? encoder.encode(dailyStats) {
            UserDefaults.standard.set(statsData, forKey: storageKey)
        }
        if let sessionsData = try? encoder.encode(sessions) {
            UserDefaults.standard.set(sessionsData, forKey: sessionsKey)
        }
    }

    private func load() {
        let decoder = JSONDecoder()
        if let statsData = UserDefaults.standard.data(forKey: storageKey),
           let stats = try? decoder.decode([DailyStats].self, from: statsData) {
            dailyStats = stats
        }
        if let sessionsData = UserDefaults.standard.data(forKey: sessionsKey),
           let loadedSessions = try? decoder.decode([TimerSession].self, from: sessionsData) {
            sessions = loadedSessions
        }
    }
}
