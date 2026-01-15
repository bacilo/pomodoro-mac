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
}
