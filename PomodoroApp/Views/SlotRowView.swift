import SwiftUI

struct SlotRowView: View {
    let slot: Slot
    let index: Int
    let isCompleted: Bool
    let isNext: Bool
    let isEditing: Bool
    let onStartEditing: () -> Void
    let onEndEditing: () -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void

    @State private var editText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Completion indicator
            ZStack {
                Circle()
                    .stroke(indicatorColor, lineWidth: 2)
                    .frame(width: 16, height: 16)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.green)
                }
            }

            // Slot number
            Text("\(index + 1).")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 18, alignment: .trailing)

            // Slot name (editable)
            if isEditing {
                TextField("Task name", text: $editText)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit {
                        onRename(editText)
                        onEndEditing()
                    }
                    .onAppear {
                        editText = slot.name
                        isFocused = true
                    }
            } else {
                Text(slot.name)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .onTapGesture(count: 2) {
                        onStartEditing()
                    }
            }

            Spacer()

            // Drag handle indicator
            Image(systemName: "line.3.horizontal")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.4))
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(isNext ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .contextMenu {
            Button("Rename") { onStartEditing() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    private var indicatorColor: Color {
        if isCompleted { return .green }
        if isNext { return .accentColor }
        return .gray.opacity(0.4)
    }
}
