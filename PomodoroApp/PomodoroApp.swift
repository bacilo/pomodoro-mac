import SwiftUI

@main
struct PomodoroApp: App {
    @StateObject private var viewModel = PomodoroViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.timerState.menuBarIcon)
                if !viewModel.menuBarTitle.isEmpty {
                    Text(viewModel.menuBarTitle)
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
