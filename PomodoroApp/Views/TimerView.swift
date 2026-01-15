import SwiftUI

struct TimerView: View {
    @ObservedObject var viewModel: PomodoroViewModel
    @State private var isDragging: Bool = false

    private let circleSize: CGFloat = 120
    private let lineWidth: CGFloat = 8

    var body: some View {
        VStack(spacing: 16) {
            // Timer circle
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
                    .frame(width: circleSize, height: circleSize)

                // Progress circle - no animation to prevent jitter
                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(strokeColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(width: circleSize, height: circleSize)
                    .rotationEffect(.degrees(-90))

                // Draggable handle (only when not idle)
                if viewModel.timerState != .idle {
                    DraggableHandle(
                        progress: viewModel.progress,
                        circleSize: circleSize,
                        lineWidth: lineWidth,
                        color: strokeColor,
                        isDragging: $isDragging,
                        onProgressChange: { newProgress in
                            viewModel.setProgress(newProgress)
                        }
                    )
                }

                // Center content
                VStack(spacing: 4) {
                    Text(viewModel.timeRemainingFormatted)
                        .font(.system(size: 28, weight: .medium, design: .monospaced))

                    Text(viewModel.timerState.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: circleSize + 20, height: circleSize + 20)

            // Control buttons
            controlButtons

            // Completed pomodoros indicator
            if viewModel.completedPomodoros > 0 {
                PomodoroDotsView(count: viewModel.completedPomodoros)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var controlButtons: some View {
        if viewModel.timerState == .idle {
            Button(action: { viewModel.startWork() }) {
                Label("Start Focus", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        } else {
            HStack(spacing: 12) {
                // Play/Pause - primary action
                Button(action: { viewModel.toggleTimer() }) {
                    Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isRunning ? .orange : .green)
                .help(viewModel.isRunning ? "Pause" : "Resume")

                // Done - complete early
                Button(action: { viewModel.completeEarly() }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .help("Done - Complete Early")

                // Skip
                Button(action: { viewModel.skip() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .help("Skip to Next")

                // Reset
                Button(action: { viewModel.reset() }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .help("Reset")
            }
        }
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

// MARK: - Pomodoro Dots View

struct PomodoroDotsView: View {
    let count: Int

    private let dotsPerRow = 4
    private let maxRows = 4
    private let maxDisplayed: Int

    init(count: Int) {
        self.count = count
        self.maxDisplayed = dotsPerRow * maxRows // 16 dots max
    }

    var body: some View {
        VStack(spacing: 4) {
            let displayCount = min(count, maxDisplayed)
            let fullRows = displayCount / dotsPerRow
            let remainder = displayCount % dotsPerRow

            // Full rows
            ForEach(0..<fullRows, id: \.self) { _ in
                dotRow(count: dotsPerRow)
            }

            // Partial row (if any)
            if remainder > 0 || count > maxDisplayed {
                HStack(spacing: 4) {
                    ForEach(0..<remainder, id: \.self) { _ in
                        dot
                    }
                    // Show overflow count after the last partial row
                    if count > maxDisplayed {
                        Text("+\(count - maxDisplayed)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func dotRow(count: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { _ in
                dot
            }
        }
    }

    private var dot: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
    }
}

// MARK: - Draggable Handle

struct DraggableHandle: View {
    let progress: Double
    let circleSize: CGFloat
    let lineWidth: CGFloat
    let color: Color
    @Binding var isDragging: Bool
    let onProgressChange: (Double) -> Void

    private var handlePosition: CGPoint {
        let radius = circleSize / 2
        let angle = CGFloat((progress * 360 - 90) * .pi / 180)
        return CGPoint(
            x: radius + CoreGraphics.cos(angle) * radius,
            y: radius + CoreGraphics.sin(angle) * radius
        )
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: lineWidth + 8, height: lineWidth + 8)
            .shadow(color: color.opacity(0.5), radius: isDragging ? 4 : 2)
            .scaleEffect(isDragging ? 1.2 : 1.0)
            .position(handlePosition)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let center = CGPoint(x: circleSize / 2, y: circleSize / 2)
                        let vector = CGPoint(
                            x: value.location.x - center.x,
                            y: value.location.y - center.y
                        )
                        var angle = atan2(vector.y, vector.x)
                        // Convert to progress (0-1), accounting for -90° rotation
                        angle += .pi / 2
                        if angle < 0 {
                            angle += 2 * .pi
                        }
                        let newProgress = angle / (2 * .pi)
                        onProgressChange(newProgress)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            // Only animate the scale, not the position
            .animation(.easeOut(duration: 0.1), value: isDragging)
    }
}

#Preview {
    TimerView(viewModel: PomodoroViewModel())
        .frame(width: 280)
}

#Preview("With Many Pomodoros") {
    let vm = PomodoroViewModel()
    vm.completedPomodoros = 10
    return TimerView(viewModel: vm)
        .frame(width: 280)
}
