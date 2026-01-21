import Foundation
import SwiftUI

/// Available macOS system sounds for timer completion
enum CompletionSound: String, CaseIterable {
    case glass = "Glass"
    case ping = "Ping"
    case pop = "Pop"
    case purr = "Purr"
    case sosumi = "Sosumi"
    case submarine = "Submarine"
    case hero = "Hero"
    case blow = "Blow"
    case bottle = "Bottle"
    case frog = "Frog"
    case funk = "Funk"
    case morse = "Morse"
    case tink = "Tink"

    var displayName: String { rawValue }
}

class Settings: ObservableObject {
    @AppStorage("workDuration") var workDuration: Int = 25
    @AppStorage("shortBreakDuration") var shortBreakDuration: Int = 5
    @AppStorage("longBreakDuration") var longBreakDuration: Int = 15
    @AppStorage("pomodorosBeforeLongBreak") var pomodorosBeforeLongBreak: Int = 4
    @AppStorage("autoStartBreaks") var autoStartBreaks: Bool = false
    @AppStorage("autoStartWork") var autoStartWork: Bool = false
    @AppStorage("playSound") var playSound: Bool = true
    @AppStorage("completionSoundName") var completionSoundName: String = CompletionSound.glass.rawValue
    @AppStorage("showNotifications") var showNotifications: Bool = true
    @AppStorage("showSlotNameInMenuBar") var showSlotNameInMenuBar: Bool = false

    var completionSound: CompletionSound {
        get { CompletionSound(rawValue: completionSoundName) ?? .glass }
        set { completionSoundName = newValue.rawValue }
    }

    var workDurationSeconds: Int { workDuration * 60 }
    var shortBreakDurationSeconds: Int { shortBreakDuration * 60 }
    var longBreakDurationSeconds: Int { longBreakDuration * 60 }

    func duration(for state: TimerState) -> Int {
        switch state {
        case .work: return workDurationSeconds
        case .shortBreak: return shortBreakDurationSeconds
        case .longBreak: return longBreakDurationSeconds
        case .idle: return 0
        }
    }
}
