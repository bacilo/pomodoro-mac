import XCTest
@testable import PomodoroApp

final class TimerStateTests: XCTestCase {

    // MARK: - Display Name Tests

    func testIdleDisplayName() {
        XCTAssertEqual(TimerState.idle.displayName, "Ready")
    }

    func testWorkDisplayName() {
        XCTAssertEqual(TimerState.work.displayName, "Focus")
    }

    func testShortBreakDisplayName() {
        XCTAssertEqual(TimerState.shortBreak.displayName, "Short Break")
    }

    func testLongBreakDisplayName() {
        XCTAssertEqual(TimerState.longBreak.displayName, "Long Break")
    }

    // MARK: - Icon Tests

    func testIdleIcon() {
        XCTAssertEqual(TimerState.idle.icon, "circle")
    }

    func testWorkIcon() {
        XCTAssertEqual(TimerState.work.icon, "brain.head.profile")
    }

    func testShortBreakIcon() {
        XCTAssertEqual(TimerState.shortBreak.icon, "cup.and.saucer")
    }

    func testLongBreakIcon() {
        XCTAssertEqual(TimerState.longBreak.icon, "figure.walk")
    }

    // MARK: - MenuBar Icon Tests

    func testMenuBarIcons() {
        XCTAssertEqual(TimerState.idle.menuBarIcon, "timer")
        XCTAssertEqual(TimerState.work.menuBarIcon, "timer")
        XCTAssertEqual(TimerState.shortBreak.menuBarIcon, "cup.and.saucer.fill")
        XCTAssertEqual(TimerState.longBreak.menuBarIcon, "figure.walk")
    }

    // MARK: - Codable Tests

    func testTimerStateEncodingDecoding() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for state in [TimerState.idle, .work, .shortBreak, .longBreak] {
            let data = try encoder.encode(state)
            let decoded = try decoder.decode(TimerState.self, from: data)
            XCTAssertEqual(decoded, state)
        }
    }

    // MARK: - TimerSession Tests

    func testTimerSessionCreation() {
        let startTime = Date()
        let endTime = Date().addingTimeInterval(1500)
        let session = TimerSession(
            state: .work,
            startTime: startTime,
            endTime: endTime,
            completed: true
        )

        XCTAssertEqual(session.state, .work)
        XCTAssertEqual(session.startTime, startTime)
        XCTAssertEqual(session.endTime, endTime)
        XCTAssertTrue(session.completed)
    }

    func testTimerSessionEncodingDecoding() throws {
        let session = TimerSession(
            state: .work,
            startTime: Date(),
            endTime: Date().addingTimeInterval(1500),
            completed: true
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(session)
        let decoded = try decoder.decode(TimerSession.self, from: data)

        XCTAssertEqual(decoded.id, session.id)
        XCTAssertEqual(decoded.state, session.state)
        XCTAssertEqual(decoded.completed, session.completed)
    }
}
