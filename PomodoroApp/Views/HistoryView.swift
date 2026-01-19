import SwiftUI

struct HistoryView: View {
    @ObservedObject var slotManager: SlotManager
    @ObservedObject var statistics: Statistics
    @Environment(\.dismiss) private var dismiss
    @State private var expandedDayIndex: Int?
    @State private var todayExpanded = false

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Completed Slots")
                    .font(.headline)

                Spacer()

                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    // Today's completed slots (special handling - syncs with slot list)
                    if slotManager.today.completedCount > 0 {
                        TodayHistoryRow(
                            slotManager: slotManager,
                            statistics: statistics,
                            isExpanded: todayExpanded,
                            onToggleExpand: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    todayExpanded.toggle()
                                }
                            }
                        )
                    }

                    // Past days (most recent first)
                    ForEach(Array(slotManager.history.enumerated().reversed()), id: \.element.id) { index, day in
                        // Skip today if it's in history (we show it separately above)
                        if day.dateString != DailySlots.todayDateString() {
                            PastDayHistoryRow(
                                dayIndex: index,
                                isExpanded: expandedDayIndex == index,
                                slotManager: slotManager,
                                statistics: statistics,
                                onToggleExpand: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedDayIndex = expandedDayIndex == index ? nil : index
                                    }
                                },
                                onDelete: {
                                    let dateString = slotManager.history[index].dateString
                                    slotManager.deleteHistoryDay(dayIndex: index)
                                    statistics.removeDay(dateString: dateString)
                                    if expandedDayIndex == index {
                                        expandedDayIndex = nil
                                    }
                                }
                            )
                        }
                    }

                    if slotManager.today.completedCount == 0 && slotManager.history.isEmpty {
                        Text("No completed slots yet")
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    }
                }
            }
        }
        .padding()
        .frame(width: 320, height: 400)
    }
}

// MARK: - Today's History Row (syncs with slot list)

struct TodayHistoryRow: View {
    @ObservedObject var slotManager: SlotManager
    @ObservedObject var statistics: Statistics
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @State private var editingSlotIndex: Int?
    @State private var editText: String = ""
    @State private var newSlotName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Day header
            HStack {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 16)

                Text("Today")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(slotManager.today.completedCount) completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { onToggleExpand() }

            // Expanded content
            if isExpanded {
                VStack(spacing: 4) {
                    // Completed slot list
                    ForEach(0..<slotManager.today.completedCount, id: \.self) { index in
                        let slot = slotManager.today.slots[index]
                        HistorySlotRowView(
                            name: slot.name,
                            isEditing: editingSlotIndex == index,
                            editText: $editText,
                            onStartEditing: {
                                editText = slot.name
                                editingSlotIndex = index
                            },
                            onEndEditing: {
                                slotManager.renameTodayCompletedSlot(at: index, newName: editText)
                                editingSlotIndex = nil
                            },
                            onDelete: {
                                slotManager.removeTodayCompletedSlot(at: index)
                                statistics.updateDayCount(dateString: DailySlots.todayDateString(), completedCount: slotManager.today.completedCount)
                            }
                        )
                    }

                    // Add slot button
                    HStack {
                        TextField("Add completed slot...", text: $newSlotName)
                            .textFieldStyle(.plain)
                            .font(.caption)
                            .onSubmit {
                                if !newSlotName.trimmingCharacters(in: .whitespaces).isEmpty {
                                    slotManager.addTodayCompletedSlot(name: newSlotName)
                                    statistics.updateDayCount(dateString: DailySlots.todayDateString(), completedCount: slotManager.today.completedCount)
                                    newSlotName = ""
                                }
                            }

                        Button(action: {
                            if !newSlotName.trimmingCharacters(in: .whitespaces).isEmpty {
                                slotManager.addTodayCompletedSlot(name: newSlotName)
                                statistics.updateDayCount(dateString: DailySlots.todayDateString(), completedCount: slotManager.today.completedCount)
                                newSlotName = ""
                            }
                        }) {
                            Image(systemName: "plus.circle")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .disabled(newSlotName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.leading, 16)
                    .padding(.top, 4)
                }
                .padding(.bottom, 8)
            }
        }
        .padding(8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Past Day History Row

struct PastDayHistoryRow: View {
    let dayIndex: Int
    let isExpanded: Bool
    @ObservedObject var slotManager: SlotManager
    @ObservedObject var statistics: Statistics
    let onToggleExpand: () -> Void
    let onDelete: () -> Void

    @State private var editingSlotIndex: Int?
    @State private var editText: String = ""
    @State private var newSlotName: String = ""

    private var day: DayHistory {
        slotManager.history[dayIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Day header
            HStack {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 16)

                Text(formattedDate)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(day.completedSlotNames.count) completed")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Delete this day")
            }
            .contentShape(Rectangle())
            .onTapGesture { onToggleExpand() }

            // Expanded content
            if isExpanded {
                VStack(spacing: 4) {
                    // Completed slot list
                    ForEach(Array(day.completedSlotNames.enumerated()), id: \.offset) { index, name in
                        HistorySlotRowView(
                            name: name,
                            isEditing: editingSlotIndex == index,
                            editText: $editText,
                            onStartEditing: {
                                editText = name
                                editingSlotIndex = index
                            },
                            onEndEditing: {
                                slotManager.renameHistorySlot(dayIndex: dayIndex, slotIndex: index, newName: editText)
                                editingSlotIndex = nil
                            },
                            onDelete: {
                                let dateString = day.dateString
                                slotManager.removeHistorySlot(dayIndex: dayIndex, slotIndex: index)
                                statistics.updateDayCount(dateString: dateString, completedCount: slotManager.history[dayIndex].completedSlotNames.count)
                            }
                        )
                    }

                    // Add slot button
                    HStack {
                        TextField("Add completed slot...", text: $newSlotName)
                            .textFieldStyle(.plain)
                            .font(.caption)
                            .onSubmit {
                                if !newSlotName.trimmingCharacters(in: .whitespaces).isEmpty {
                                    let dateString = day.dateString
                                    slotManager.addHistorySlot(dayIndex: dayIndex, name: newSlotName)
                                    statistics.updateDayCount(dateString: dateString, completedCount: slotManager.history[dayIndex].completedSlotNames.count)
                                    newSlotName = ""
                                }
                            }

                        Button(action: {
                            if !newSlotName.trimmingCharacters(in: .whitespaces).isEmpty {
                                let dateString = day.dateString
                                slotManager.addHistorySlot(dayIndex: dayIndex, name: newSlotName)
                                statistics.updateDayCount(dateString: dateString, completedCount: slotManager.history[dayIndex].completedSlotNames.count)
                                newSlotName = ""
                            }
                        }) {
                            Image(systemName: "plus.circle")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .disabled(newSlotName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.leading, 16)
                    .padding(.top, 4)
                }
                .padding(.bottom, 8)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: day.dateString) else {
            return day.dateString
        }
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - History Slot Row

struct HistorySlotRowView: View {
    let name: String
    let isEditing: Bool
    @Binding var editText: String
    let onStartEditing: () -> Void
    let onEndEditing: () -> Void
    let onDelete: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)

            if isEditing {
                TextField("Slot name", text: $editText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .focused($isFocused)
                    .onSubmit { onEndEditing() }
                    .onAppear { isFocused = true }
            } else {
                Text(name)
                    .font(.caption)
                    .onTapGesture(count: 2) { onStartEditing() }

                Spacer()

                Button(action: onStartEditing) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 16)
        .padding(.vertical, 2)
    }
}

#Preview {
    HistoryView(slotManager: SlotManager(), statistics: Statistics())
}
