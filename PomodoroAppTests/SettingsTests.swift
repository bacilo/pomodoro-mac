import XCTest
@testable import PomodoroApp

final class SettingsTests: XCTestCase {
    var settings: Settings!

    override func setUp() {
        super.setUp()
        settings = Settings()
        // Reset to defaults for each test
        settings.workDuration = 25
        settings.shortBreakDuration = 5
        settings.longBreakDuration = 15
        settings.pomodorosBeforeLongBreak = 4
        settings.autoStartBreaks = false
        settings.autoStartWork = false
    }

    override func tearDown() {
        settings = nil
        super.tearDown()
    }

    // MARK: - Duration Conversion Tests

    func testWorkDurationInSeconds() {
        settings.workDuration = 25
        XCTAssertEqual(settings.workDurationSeconds, 1500)
    }

    func testShortBreakDurationInSeconds() {
        settings.shortBreakDuration = 5
        XCTAssertEqual(settings.shortBreakDurationSeconds, 300)
    }

    func testLongBreakDurationInSeconds() {
        settings.longBreakDuration = 15
        XCTAssertEqual(settings.longBreakDurationSeconds, 900)
    }

    // MARK: - Duration for State Tests

    func testDurationForWorkState() {
        settings.workDuration = 30
        XCTAssertEqual(settings.duration(for: .work), 1800)
    }

    func testDurationForShortBreakState() {
        settings.shortBreakDuration = 10
        XCTAssertEqual(settings.duration(for: .shortBreak), 600)
    }

    func testDurationForLongBreakState() {
        settings.longBreakDuration = 20
        XCTAssertEqual(settings.duration(for: .longBreak), 1200)
    }

    func testDurationForIdleState() {
        XCTAssertEqual(settings.duration(for: .idle), 0)
    }

    // MARK: - Default Values Tests

    func testDefaultWorkDuration() {
        let freshSettings = Settings()
        // Note: This depends on UserDefaults state, may need reset
        XCTAssertGreaterThan(freshSettings.workDuration, 0)
    }

    func testDefaultPomodorosBeforeLongBreak() {
        XCTAssertEqual(settings.pomodorosBeforeLongBreak, 4)
    }
}
