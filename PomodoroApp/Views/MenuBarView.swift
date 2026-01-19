import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: PomodoroViewModel
    @State private var selectedTab: Tab = .timer

    // Placeholder prompting state
    @State private var showingPlaceholderPrompt = false
    @State private var placeholdersToFill: [String] = []
    @State private var currentPlaceholderIndex = 0
    @State private var placeholderReplacements: [String: String] = [:]
    @State private var currentPlaceholderValue: String = ""
    @State private var hasCheckedPlaceholders = false

    enum Tab {
        case timer
        case slots
        case stats
        case settings
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Image(systemName: "timer").tag(Tab.timer)
                Image(systemName: "list.bullet.rectangle").tag(Tab.slots)
                Image(systemName: "chart.bar").tag(Tab.stats)
                Image(systemName: "gearshape").tag(Tab.settings)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                Group {
                    switch selectedTab {
                    case .timer:
                        TimerView(viewModel: viewModel)
                    case .slots:
                        SlotsView(slotManager: viewModel.slotManager)
                    case .stats:
                        StatsView(statistics: viewModel.statistics, slotManager: viewModel.slotManager)
                    case .settings:
                        SettingsView(settings: viewModel.settings)
                    }
                }
            }
            .frame(height: 420)

            Divider()

            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Text("Pomodoro")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 280)
        .onAppear {
            checkForUnfilledPlaceholders()
        }
        .sheet(isPresented: $showingPlaceholderPrompt) {
            PlaceholderPromptView(
                placeholder: placeholdersToFill.indices.contains(currentPlaceholderIndex)
                    ? placeholdersToFill[currentPlaceholderIndex] : "",
                value: $currentPlaceholderValue,
                onSubmit: { submitPlaceholderValue() },
                onCancel: { cancelPlaceholderPrompt() }
            )
        }
    }

    private func checkForUnfilledPlaceholders() {
        // Only check once per popover open
        guard !hasCheckedPlaceholders else { return }
        hasCheckedPlaceholders = true

        let placeholders = viewModel.slotManager.getTodayUnfilledPlaceholders()
        if !placeholders.isEmpty {
            placeholdersToFill = placeholders
            currentPlaceholderIndex = 0
            placeholderReplacements = [:]
            currentPlaceholderValue = ""
            showingPlaceholderPrompt = true
        }
    }

    private func submitPlaceholderValue() {
        let placeholder = placeholdersToFill[currentPlaceholderIndex]
        placeholderReplacements[placeholder] = currentPlaceholderValue

        currentPlaceholderIndex += 1
        currentPlaceholderValue = ""

        if currentPlaceholderIndex >= placeholdersToFill.count {
            // All placeholders filled, apply replacements
            showingPlaceholderPrompt = false
            viewModel.slotManager.fillTodayPlaceholders(placeholderReplacements)
        }
    }

    private func cancelPlaceholderPrompt() {
        showingPlaceholderPrompt = false
        placeholdersToFill = []
        currentPlaceholderIndex = 0
        placeholderReplacements = [:]
        currentPlaceholderValue = ""
    }
}

#Preview {
    MenuBarView(viewModel: PomodoroViewModel())
}
