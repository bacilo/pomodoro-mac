import Foundation
import Combine
import UserNotifications
import AppKit

@MainActor
class PomodoroViewModel: ObservableObject {
    @Published var timerState: TimerState = .idle
    @Published var timeRemaining: Int = 0
    @Published var isRunning: Bool = false
    @Published var completedPomodoros: Int = 0

    let settings: Settings
    let statistics: Statistics

    private var timer: Timer?
    private var sessionStartTime: Date?

    init(settings: Settings = Settings(), statistics: Statistics = Statistics()) {
        self.settings = settings
        self.statistics = statistics
        self.timeRemaining = settings.workDurationSeconds
        requestNotificationPermission()
    }

    var progress: Double {
        guard timerState != .idle else { return 0 }
        let total = settings.duration(for: timerState)
        guard total > 0 else { return 0 }
        return Double(total - timeRemaining) / Double(total)
    }

    var timeRemainingFormatted: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var menuBarTitle: String {
        if isRunning || timerState != .idle {
            return timeRemainingFormatted
        }
        return ""
    }

    func startWork() {
        timerState = .work
        timeRemaining = settings.workDurationSeconds
        sessionStartTime = Date()
        startTimer()
    }

    func startShortBreak() {
        timerState = .shortBreak
        timeRemaining = settings.shortBreakDurationSeconds
        sessionStartTime = Date()
        startTimer()
    }

    func startLongBreak() {
        timerState = .longBreak
        timeRemaining = settings.longBreakDurationSeconds
        sessionStartTime = Date()
        startTimer()
    }

    func toggleTimer() {
        if isRunning {
            pause()
        } else if timerState == .idle {
            startWork()
        } else {
            resume()
        }
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func resume() {
        guard timerState != .idle else { return }
        startTimer()
    }

    func reset() {
        pause()
        recordIncompleteSession()
        timerState = .idle
        timeRemaining = settings.workDurationSeconds
        sessionStartTime = nil
    }

    func skip() {
        recordIncompleteSession()
        transitionToNextState()
    }

    func completeEarly() {
        guard timerState != .idle else { return }
        pause()

        let completedState = timerState
        if completedState == .work {
            completedPomodoros += 1
            // Record partial duration based on time elapsed
            let totalDuration = settings.duration(for: timerState)
            let elapsedSeconds = totalDuration - timeRemaining
            let elapsedMinutes = max(1, elapsedSeconds / 60)
            statistics.recordCompletedPomodoro(durationMinutes: elapsedMinutes)
        }

        recordCompletedSession()
        sendNotification(for: completedState)
        playCompletionSound()

        transitionToNextState()
    }

    func setProgress(_ newProgress: Double) {
        guard timerState != .idle else { return }
        let totalDuration = settings.duration(for: timerState)
        let clampedProgress = max(0, min(1, newProgress))
        timeRemaining = Int(Double(totalDuration) * (1 - clampedProgress))
    }

    private func startTimer() {
        isRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard timeRemaining > 0 else {
            timerCompleted()
            return
        }
        timeRemaining -= 1
    }

    private func timerCompleted() {
        pause()

        let completedState = timerState
        if completedState == .work {
            completedPomodoros += 1
            statistics.recordCompletedPomodoro(durationMinutes: settings.workDuration)
        }

        recordCompletedSession()
        sendNotification(for: completedState)
        playCompletionSound()

        transitionToNextState()
    }

    private func transitionToNextState() {
        switch timerState {
        case .work:
            if completedPomodoros > 0 && completedPomodoros % settings.pomodorosBeforeLongBreak == 0 {
                timerState = .longBreak
                timeRemaining = settings.longBreakDurationSeconds
            } else {
                timerState = .shortBreak
                timeRemaining = settings.shortBreakDurationSeconds
            }
            if settings.autoStartBreaks {
                sessionStartTime = Date()
                startTimer()
            }
        case .shortBreak, .longBreak:
            timerState = .work
            timeRemaining = settings.workDurationSeconds
            if settings.autoStartWork {
                sessionStartTime = Date()
                startTimer()
            }
        case .idle:
            break
        }
    }

    private func recordCompletedSession() {
        guard let startTime = sessionStartTime else { return }
        let session = TimerSession(
            state: timerState,
            startTime: startTime,
            endTime: Date(),
            completed: true
        )
        statistics.recordSession(session)
        sessionStartTime = nil
    }

    private func recordIncompleteSession() {
        guard let startTime = sessionStartTime else { return }
        let session = TimerSession(
            state: timerState,
            startTime: startTime,
            endTime: Date(),
            completed: false
        )
        statistics.recordSession(session)
        sessionStartTime = nil
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification(for state: TimerState) {
        guard settings.showNotifications else { return }

        let content = UNMutableNotificationContent()
        switch state {
        case .work:
            content.title = "Focus Session Complete!"
            content.body = "Great work! Time for a break."
        case .shortBreak:
            content.title = "Break Over"
            content.body = "Ready to focus again?"
        case .longBreak:
            content.title = "Long Break Over"
            content.body = "Feeling refreshed? Let's get back to work!"
        case .idle:
            return
        }

        if settings.playSound {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func playCompletionSound() {
        guard settings.playSound else { return }
        NSSound.beep()
    }
}
