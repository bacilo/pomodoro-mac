import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: PomodoroViewModel
    @State private var selectedTab: Tab = .timer

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
            .frame(height: 340)

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
    }
}

#Preview {
    MenuBarView(viewModel: PomodoroViewModel())
}
