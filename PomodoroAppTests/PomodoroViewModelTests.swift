import XCTest
@testable import PomodoroApp

@MainActor
final class PomodoroViewModelTests: XCTestCase {
    var viewModel: PomodoroViewModel!
    var settings: Settings!
    var statistics: Statistics!

    override func setUp() async throws {
        try await super.setUp()
        // Clear UserDefaults for clean tests
        UserDefaults.standard.removeObject(forKey: "pomodoroStatistics")
        UserDefaults.standard.removeObject(forKey: "pomodoroSessions")

        settings = Settings()
        settings.workDuration = 25
        settings.shortBreakDuration = 5
        settings.longBreakDuration = 15
        settings.pomodorosBeforeLongBreak = 4
        settings.autoStartBreaks = false
        settings.autoStartWork = false

        statistics = Statistics()
        viewModel = PomodoroViewModel(settings: settings, statistics: statistics)
    }

    override func tearDown() async throws {
        viewModel = nil
        settings = nil
        statistics = nil
        UserDefaults.standard.removeObject(forKey: "pomodoroStatistics")
        UserDefaults.standard.removeObject(forKey: "pomodoroSessions")
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertEqual(viewModel.timerState, .idle)
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertEqual(viewModel.completedPomodoros, 0)
    }

    func testInitialTimeRemaining() {
        XCTAssertEqual(viewModel.timeRemaining, settings.workDurationSeconds)
    }

    // MARK: - Start Tests

    func testStartWork() {
        viewModel.startWork()

        XCTAssertEqual(viewModel.timerState, .work)
        XCTAssertTrue(viewModel.isRunning)
        XCTAssertEqual(viewModel.timeRemaining, settings.workDurationSeconds)
    }

    func testStartShortBreak() {
        viewModel.startShortBreak()

        XCTAssertEqual(viewModel.timerState, .shortBreak)
        XCTAssertTrue(viewModel.isRunning)
        XCTAssertEqual(viewModel.timeRemaining, settings.shortBreakDurationSeconds)
    }

    func testStartLongBreak() {
        viewModel.startLongBreak()

        XCTAssertEqual(viewModel.timerState, .longBreak)
        XCTAssertTrue(viewModel.isRunning)
        XCTAssertEqual(viewModel.timeRemaining, settings.longBreakDurationSeconds)
    }

    // MARK: - Pause/Resume Tests

    func testPause() {
        viewModel.startWork()
        viewModel.pause()

        XCTAssertFalse(viewModel.isRunning)
        XCTAssertEqual(viewModel.timerState, .work) // State preserved
    }

    func testResume() {
        viewModel.startWork()
        viewModel.pause()
        viewModel.resume()

        XCTAssertTrue(viewModel.isRunning)
    }

    func testResumeFromIdleDoesNothing() {
        viewModel.resume()

        XCTAssertFalse(viewModel.isRunning)
        XCTAssertEqual(viewModel.timerState, .idle)
    }

    // MARK: - Toggle Tests

    func testToggleFromIdle() {
        viewModel.toggleTimer()

        XCTAssertEqual(viewModel.timerState, .work)
        XCTAssertTrue(viewModel.isRunning)
    }

    func testToggleWhileRunning() {
        viewModel.startWork()
        viewModel.toggleTimer()

        XCTAssertFalse(viewModel.isRunning)
    }

    func testToggleWhilePaused() {
        viewModel.startWork()
        viewModel.pause()
        viewModel.toggleTimer()

        XCTAssertTrue(viewModel.isRunning)
    }

    // MARK: - Reset Tests

    func testReset() {
        viewModel.startWork()
        viewModel.reset()

        XCTAssertEqual(viewModel.timerState, .idle)
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertEqual(viewModel.timeRemaining, settings.workDurationSeconds)
    }

    // MARK: - Skip Tests

    func testSkipFromWork() {
        viewModel.startWork()
        viewModel.skip()

        XCTAssertEqual(viewModel.timerState, .shortBreak)
    }

    func testSkipFromShortBreak() {
        viewModel.startShortBreak()
        viewModel.skip()

        XCTAssertEqual(viewModel.timerState, .work)
    }

    func testSkipToLongBreakAfterEnoughPomodoros() {
        // Simulate completing enough pomodoros
        viewModel.completedPomodoros = settings.pomodorosBeforeLongBreak
        viewModel.startWork()
        viewModel.skip()

        XCTAssertEqual(viewModel.timerState, .longBreak)
    }

    // MARK: - Progress Tests

    func testProgressWhenIdle() {
        XCTAssertEqual(viewModel.progress, 0)
    }

    func testProgressAtStart() {
        viewModel.startWork()
        XCTAssertEqual(viewModel.progress, 0)
    }

    func testProgressCalculation() {
        viewModel.startWork()
        // Simulate half time elapsed
        viewModel.timeRemaining = settings.workDurationSeconds / 2

        let expectedProgress = 0.5
        XCTAssertEqual(viewModel.progress, expectedProgress, accuracy: 0.01)
    }

    // MARK: - Formatting Tests

    func testTimeRemainingFormatted() {
        viewModel.timeRemaining = 1500 // 25:00
        XCTAssertEqual(viewModel.timeRemainingFormatted, "25:00")

        viewModel.timeRemaining = 65 // 01:05
        XCTAssertEqual(viewModel.timeRemainingFormatted, "01:05")

        viewModel.timeRemaining = 5 // 00:05
        XCTAssertEqual(viewModel.timeRemainingFormatted, "00:05")
    }

    func testMenuBarTitleWhenIdle() {
        XCTAssertEqual(viewModel.menuBarTitle, "")
    }

    func testMenuBarTitleWhenRunning() {
        viewModel.startWork()
        XCTAssertFalse(viewModel.menuBarTitle.isEmpty)
    }

    // MARK: - Complete Early Tests

    func testCompleteEarlyFromWork() {
        viewModel.startWork()
        viewModel.timeRemaining = settings.workDurationSeconds / 2  // Halfway through

        viewModel.completeEarly()

        // Should transition to break and increment completed pomodoros
        XCTAssertEqual(viewModel.completedPomodoros, 1)
        XCTAssertEqual(viewModel.timerState, .shortBreak)
        XCTAssertFalse(viewModel.isRunning)
    }

    func testCompleteEarlyFromBreak() {
        viewModel.startShortBreak()
        viewModel.timeRemaining = settings.shortBreakDurationSeconds / 2

        let pomodorosBefore = viewModel.completedPomodoros
        viewModel.completeEarly()

        // Should transition to work, pomodoro count unchanged
        XCTAssertEqual(viewModel.completedPomodoros, pomodorosBefore)
        XCTAssertEqual(viewModel.timerState, .work)
    }

    func testCompleteEarlyFromIdleDoesNothing() {
        viewModel.completeEarly()

        XCTAssertEqual(viewModel.timerState, .idle)
        XCTAssertEqual(viewModel.completedPomodoros, 0)
    }

    func testCompleteEarlyRecordsPartialDuration() {
        viewModel.startWork()
        // Simulate 10 minutes elapsed (600 seconds remaining of 1500)
        viewModel.timeRemaining = settings.workDurationSeconds - 600

        viewModel.completeEarly()

        // Check that statistics recorded the partial duration
        XCTAssertEqual(statistics.todayStats.completedPomodoros, 1)
        XCTAssertEqual(statistics.todayStats.totalFocusMinutes, 10)
    }

    // MARK: - Set Progress Tests

    func testSetProgressUpdatesTimeRemaining() {
        viewModel.startWork()
        viewModel.pause()

        viewModel.setProgress(0.5)

        let expectedTimeRemaining = settings.workDurationSeconds / 2
        XCTAssertEqual(viewModel.timeRemaining, expectedTimeRemaining)
    }

    func testSetProgressToZero() {
        viewModel.startWork()
        viewModel.pause()

        viewModel.setProgress(0)

        XCTAssertEqual(viewModel.timeRemaining, settings.workDurationSeconds)
    }

    func testSetProgressToOne() {
        viewModel.startWork()
        viewModel.pause()

        viewModel.setProgress(1.0)

        XCTAssertEqual(viewModel.timeRemaining, 0)
    }

    func testSetProgressClampsValues() {
        viewModel.startWork()
        viewModel.pause()

        viewModel.setProgress(1.5)  // Over 100%
        XCTAssertEqual(viewModel.timeRemaining, 0)

        viewModel.timeRemaining = settings.workDurationSeconds
        viewModel.setProgress(-0.5)  // Negative
        XCTAssertEqual(viewModel.timeRemaining, settings.workDurationSeconds)
    }

    func testSetProgressDoesNothingWhenIdle() {
        let initialTime = viewModel.timeRemaining

        viewModel.setProgress(0.5)

        XCTAssertEqual(viewModel.timeRemaining, initialTime)
    }
}
