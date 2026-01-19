import SwiftUI

struct StatsView: View {
    @ObservedObject var statistics: Statistics
    @ObservedObject var slotManager: SlotManager
    @State private var showingHistory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Statistics")
                    .font(.headline)

                Spacer()

                Button(action: { showingHistory = true }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("View slot history")
            }

            HStack(spacing: 20) {
                StatBox(title: "Today", value: statistics.todayStats.completedPomodoros)
                StatBox(title: "This Week", value: statistics.weeklyPomodoros)
                StatBox(title: "This Month", value: statistics.monthlyPomodoros)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Last 7 Days")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(statistics.last7Days) { day in
                        VStack(spacing: 4) {
                            BarView(value: day.completedPomodoros, maxValue: maxInWeek)

                            Text(dayLabel(day.dateString))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 80)
            }

            if statistics.todayStats.totalFocusMinutes > 0 {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text("Total focus today: \(statistics.todayStats.totalFocusMinutes) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .sheet(isPresented: $showingHistory) {
            HistoryView(slotManager: slotManager)
        }
    }

    private var maxInWeek: Int {
        max(statistics.last7Days.map { $0.completedPomodoros }.max() ?? 1, 1)
    }

    private func dayLabel(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return "" }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        return dayFormatter.string(from: date)
    }
}

struct StatBox: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct BarView: View {
    let value: Int
    let maxValue: Int

    var body: some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: 2)
                .fill(value > 0 ? Color.red : Color.gray.opacity(0.3))
                .frame(width: 28, height: max(4, CGFloat(value) / CGFloat(maxValue) * 50))

            Text("\(value)")
                .font(.system(size: 10))
                .foregroundColor(value > 0 ? .primary : .secondary)
        }
    }
}

#Preview {
    StatsView(statistics: Statistics(), slotManager: SlotManager())
}
