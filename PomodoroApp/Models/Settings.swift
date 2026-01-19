import Foundation
import SwiftUI

class Settings: ObservableObject {
    @AppStorage("workDuration") var workDuration: Int = 25
    @AppStorage("shortBreakDuration") var shortBreakDuration: Int = 5
    @AppStorage("longBreakDuration") var longBreakDuration: Int = 15
    @AppStorage("pomodorosBeforeLongBreak") var pomodorosBeforeLongBreak: Int = 4
    @AppStorage("autoStartBreaks") var autoStartBreaks: Bool = false
    @AppStorage("autoStartWork") var autoStartWork: Bool = false
    @AppStorage("playSound") var playSound: Bool = true
    @AppStorage("showNotifications") var showNotifications: Bool = true
    @AppStorage("showSlotNameInMenuBar") var showSlotNameInMenuBar: Bool = false

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
