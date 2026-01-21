import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @State private var selectedSound: CompletionSound = .glass

    var body: some View {
        Form {
            Section("Durations") {
                Stepper(value: $settings.workDuration, in: 1...60) {
                    HStack {
                        Text("Focus")
                        Spacer()
                        Text("\(settings.workDuration) min")
                            .foregroundColor(.secondary)
                    }
                }

                Stepper(value: $settings.shortBreakDuration, in: 1...30) {
                    HStack {
                        Text("Short Break")
                        Spacer()
                        Text("\(settings.shortBreakDuration) min")
                            .foregroundColor(.secondary)
                    }
                }

                Stepper(value: $settings.longBreakDuration, in: 1...60) {
                    HStack {
                        Text("Long Break")
                        Spacer()
                        Text("\(settings.longBreakDuration) min")
                            .foregroundColor(.secondary)
                    }
                }

                Stepper(value: $settings.pomodorosBeforeLongBreak, in: 1...10) {
                    HStack {
                        Text("Long Break After")
                        Spacer()
                        Text("\(settings.pomodorosBeforeLongBreak) pomodoros")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Automation") {
                Toggle("Auto-start breaks", isOn: $settings.autoStartBreaks)
                Toggle("Auto-start work sessions", isOn: $settings.autoStartWork)
            }

            Section("Notifications") {
                Toggle("Show notifications", isOn: $settings.showNotifications)
                Toggle("Play sound", isOn: $settings.playSound)

                if settings.playSound {
                    Picker("Sound", selection: $selectedSound) {
                        ForEach(CompletionSound.allCases, id: \.self) { sound in
                            Text(sound.displayName).tag(sound)
                        }
                    }
                    .onChange(of: selectedSound) { newValue in
                        settings.completionSound = newValue
                        // Play preview
                        if let sound = NSSound(named: NSSound.Name(newValue.rawValue)) {
                            sound.play()
                        }
                    }
                }
            }
            .onAppear {
                selectedSound = settings.completionSound
            }

            Section("Menu Bar") {
                Toggle("Show slot name", isOn: $settings.showSlotNameInMenuBar)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

#Preview {
    SettingsView(settings: Settings())
}
