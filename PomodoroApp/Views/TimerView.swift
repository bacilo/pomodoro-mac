import SwiftUI

struct TimerView: View {
    @ObservedObject var viewModel: PomodoroViewModel
    @State private var isDragging: Bool = false

    private let circleSize: CGFloat = 120
    private let lineWidth: CGFloat = 8

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
                    .frame(width: circleSize, height: circleSize)

                // Progress circle
                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(strokeColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(width: circleSize, height: circleSize)
                    .rotationEffect(.degrees(-90))
                    .animation(isDragging ? nil : .linear(duration: 0.5), value: viewModel.progress)

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
            HStack(spacing: 8) {
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

                    Button(action: { viewModel.completeEarly() }) {
                        Label("Done", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    Button(action: { viewModel.skip() }) {
                        Label("Skip", systemImage: "forward.fill")
                    }
                    .buttonStyle(.bordered)

                    Button(action: { viewModel.reset() }) {
                        Image(systemName: "stop.fill")
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
            .scaleEffect(isDragging ? 1.3 : 1.0)
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
            .animation(.easeOut(duration: 0.15), value: isDragging)
    }
}

#Preview {
    TimerView(viewModel: PomodoroViewModel())
        .frame(width: 280)
}
