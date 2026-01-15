import XCTest
@testable import PomodoroApp

final class StatisticsTests: XCTestCase {
    var statistics: Statistics!

    override func setUp() {
        super.setUp()
        // Clear any existing data for clean tests
        UserDefaults.standard.removeObject(forKey: "pomodoroStatistics")
        UserDefaults.standard.removeObject(forKey: "pomodoroSessions")
        statistics = Statistics()
    }

    override func tearDown() {
        statistics = nil
        UserDefaults.standard.removeObject(forKey: "pomodoroStatistics")
        UserDefaults.standard.removeObject(forKey: "pomodoroSessions")
        super.tearDown()
    }

    // MARK: - DailyStats Tests

    func testDailyStatsInitialization() {
        let stats = DailyStats()
        XCTAssertEqual(stats.completedPomodoros, 0)
        XCTAssertEqual(stats.totalFocusMinutes, 0)
        XCTAssertFalse(stats.dateString.isEmpty)
    }

    func testDailyStatsDateFormat() {
        let stats = DailyStats()
        // Should be in yyyy-MM-dd format
        let components = stats.dateString.split(separator: "-")
        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(components[0].count, 4) // year
        XCTAssertEqual(components[1].count, 2) // month
        XCTAssertEqual(components[2].count, 2) // day
    }

    func testDailyStatsIdentifiable() {
        let stats = DailyStats()
        XCTAssertEqual(stats.id, stats.dateString)
    }

    // MARK: - Recording Tests

    func testRecordCompletedPomodoro() {
        statistics.recordCompletedPomodoro(durationMinutes: 25)

        XCTAssertEqual(statistics.todayStats.completedPomodoros, 1)
        XCTAssertEqual(statistics.todayStats.totalFocusMinutes, 25)
    }

    func testRecordMultiplePomodoros() {
        statistics.recordCompletedPomodoro(durationMinutes: 25)
        statistics.recordCompletedPomodoro(durationMinutes: 25)
        statistics.recordCompletedPomodoro(durationMinutes: 30)

        XCTAssertEqual(statistics.todayStats.completedPomodoros, 3)
        XCTAssertEqual(statistics.todayStats.totalFocusMinutes, 80)
    }

    func testRecordSession() {
        let session = TimerSession(
            state: .work,
            startTime: Date(),
            endTime: Date().addingTimeInterval(1500),
            completed: true
        )

        statistics.recordSession(session)

        XCTAssertEqual(statistics.sessions.count, 1)
        XCTAssertEqual(statistics.sessions.first?.state, .work)
    }

    // MARK: - Aggregation Tests

    func testWeeklyPomodoros() {
        // Record some pomodoros today
        statistics.recordCompletedPomodoro(durationMinutes: 25)
        statistics.recordCompletedPomodoro(durationMinutes: 25)

        XCTAssertGreaterThanOrEqual(statistics.weeklyPomodoros, 2)
    }

    func testMonthlyPomodoros() {
        statistics.recordCompletedPomodoro(durationMinutes: 25)

        XCTAssertGreaterThanOrEqual(statistics.monthlyPomodoros, 1)
    }

    func testLast7DaysCount() {
        let last7Days = statistics.last7Days
        XCTAssertEqual(last7Days.count, 7)
    }

    func testLast7DaysOrder() {
        let last7Days = statistics.last7Days
        // Should be ordered oldest to newest
        for i in 0..<(last7Days.count - 1) {
            XCTAssertLessThan(last7Days[i].dateString, last7Days[i + 1].dateString)
        }
    }

    // MARK: - Persistence Tests

    func testStatisticsPersistence() {
        statistics.recordCompletedPomodoro(durationMinutes: 25)

        // Create new instance to test loading
        let newStatistics = Statistics()

        XCTAssertEqual(newStatistics.todayStats.completedPomodoros, 1)
    }

    // MARK: - Session Limit Tests

    func testSessionLimitEnforced() {
        // Record more than 1000 sessions
        for _ in 0..<1005 {
            let session = TimerSession(
                state: .work,
                startTime: Date(),
                endTime: Date(),
                completed: true
            )
            statistics.recordSession(session)
        }

        XCTAssertLessThanOrEqual(statistics.sessions.count, 1000)
    }
}
