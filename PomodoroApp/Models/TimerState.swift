import Foundation

enum TimerState: String, Codable {
    case idle
    case work
    case shortBreak
    case longBreak

    var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .work: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    var icon: String {
        switch self {
        case .idle: return "circle"
        case .work: return "brain.head.profile"
        case .shortBreak: return "cup.and.saucer"
        case .longBreak: return "figure.walk"
        }
    }

    var menuBarIcon: String {
        switch self {
        case .idle: return "timer"
        case .work: return "timer"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "figure.walk"
        }
    }
}

struct TimerSession: Identifiable, Codable {
    let id: UUID
    let state: TimerState
    let startTime: Date
    let endTime: Date
    let completed: Bool

    init(id: UUID = UUID(), state: TimerState, startTime: Date, endTime: Date, completed: Bool) {
        self.id = id
        self.state = state
        self.startTime = startTime
        self.endTime = endTime
        self.completed = completed
    }
}
