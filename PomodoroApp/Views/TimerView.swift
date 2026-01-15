import SwiftUI

struct TimerView: View {
    @ObservedObject var viewModel: PomodoroViewModel

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(strokeColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: viewModel.progress)

                VStack(spacing: 4) {
                    Text(viewModel.timeRemainingFormatted)
                        .font(.system(size: 28, weight: .medium, design: .monospaced))

                    Text(viewModel.timerState.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 12) {
                if viewModel.timerState == .idle {
                    Button(action: { viewModel.startWork() }) {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else {
                    Button(action: { viewModel.toggleTimer() }) {
                        Label(viewModel.isRunning ? "Pause" : "Resume",
                              systemImage: viewModel.isRunning ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.isRunning ? .orange : .green)

                    Button(action: { viewModel.skip() }) {
                        Label("Skip", systemImage: "forward.fill")
                    }
                    .buttonStyle(.bordered)

                    Button(action: { viewModel.reset() }) {
                        Label("Reset", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }

            if viewModel.completedPomodoros > 0 {
                HStack {
                    ForEach(0..<min(viewModel.completedPomodoros, 4), id: \.self) { _ in
                        Image(systemName: "circle.fill")
                            .foregroundColor(.red)
                            .font(.caption2)
                    }
                    if viewModel.completedPomodoros > 4 {
                        Text("+\(viewModel.completedPomodoros - 4)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
    }

    private var strokeColor: Color {
        switch viewModel.timerState {
        case .idle: return .gray
        case .work: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }
}

#Preview {
    TimerView(viewModel: PomodoroViewModel())
        .frame(width: 280)
}
