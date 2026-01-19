import SwiftUI

struct HistoryView: View {
    @ObservedObject var slotManager: SlotManager
    @Environment(\.dismiss) private var dismiss
    @State private var expandedDayIndex: Int?

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Slot History")
                    .font(.headline)

                Spacer()

                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
            }

            if slotManager.history.isEmpty {
                Spacer()
                Text("No history yet")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // Show history in reverse order (most recent first)
                        ForEach(Array(slotManager.history.enumerated().reversed()), id: \.offset) { index, day in
                            HistoryDayRow(
                                day: day,
                                dayIndex: index,
                                isExpanded: expandedDayIndex == index,
                                slotManager: slotManager,
                                onToggleExpand: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedDayIndex = expandedDayIndex == index ? nil : index
                                    }
                                },
                                onDelete: {
                                    slotManager.deleteHistoryDay(dayIndex: index)
                                    if expandedDayIndex == index {
                                        expandedDayIndex = nil
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 320, height: 400)
    }
}

// MARK: - History Day Row

struct HistoryDayRow: View {
    let day: DailySlots
    let dayIndex: Int
    let isExpanded: Bool
    @ObservedObject var slotManager: SlotManager
    let onToggleExpand: () -> Void
    let onDelete: () -> Void

    @State private var editingSlotIndex: Int?
    @State private var editText: String = ""

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

                Text("\(day.completedCount)/\(day.slots.count)")
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
                    // Completion count adjuster
                    HStack {
                        Text("Completed:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Stepper(
                            "\(day.completedCount)",
                            value: Binding(
                                get: { day.completedCount },
                                set: { slotManager.setHistoryCompletedCount(dayIndex: dayIndex, count: $0) }
                            ),
                            in: 0...day.slots.count
                        )
                        .frame(width: 100)
                    }
                    .padding(.leading, 16)
                    .padding(.top, 4)

                    Divider()
                        .padding(.leading, 16)

                    // Slot list
                    ForEach(Array(day.slots.enumerated()), id: \.element.id) { slotIndex, slot in
                        HistorySlotRow(
                            slot: slot,
                            slotIndex: slotIndex,
                            isCompleted: slotIndex < day.completedCount,
                            isEditing: editingSlotIndex == slotIndex,
                            editText: $editText,
                            onStartEditing: {
                                editText = slot.name
                                editingSlotIndex = slotIndex
                            },
                            onEndEditing: {
                                slotManager.updateHistorySlot(dayIndex: dayIndex, slotIndex: slotIndex, newName: editText)
                                editingSlotIndex = nil
                            },
                            onDelete: {
                                slotManager.removeHistorySlot(dayIndex: dayIndex, slotIndex: slotIndex)
                            }
                        )
                    }

                    // Add slot button
                    Button(action: {
                        slotManager.addHistorySlot(dayIndex: dayIndex)
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Slot")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
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

struct HistorySlotRow: View {
    let slot: Slot
    let slotIndex: Int
    let isCompleted: Bool
    let isEditing: Bool
    @Binding var editText: String
    let onStartEditing: () -> Void
    let onEndEditing: () -> Void
    let onDelete: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCompleted ? .green : .secondary)
                .font(.caption)

            if isEditing {
                TextField("Slot name", text: $editText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .focused($isFocused)
                    .onSubmit { onEndEditing() }
                    .onAppear { isFocused = true }
            } else {
                Text(slot.name)
                    .font(.caption)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted)
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
    let manager = SlotManager()
    // Add some test history
    return HistoryView(slotManager: manager)
}
