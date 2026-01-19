import SwiftUI

struct SlotsView: View {
    @ObservedObject var slotManager: SlotManager
    @State private var editingSlotId: UUID?
    @State private var showingTemplates = false
    @State private var draggedSlot: Slot?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Today's Slots")
                    .font(.headline)

                Spacer()

                Button(action: { showingTemplates = true }) {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Configure default templates")
            }

            // Progress and reset
            HStack {
                Text("\(slotManager.today.completedCount)/\(slotManager.totalSlots) completed")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if slotManager.today.completedCount > 0 {
                    Button("Reset") {
                        slotManager.resetCompletions()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }

            // Slot list - using VStack instead of List for proper rendering in ScrollView
            VStack(spacing: 2) {
                ForEach(Array(slotManager.today.slots.enumerated()), id: \.element.id) { index, slot in
                    SlotRowView(
                        slot: slot,
                        index: index,
                        isCompleted: slotManager.isCompleted(at: index),
                        isNext: slotManager.nextIncompleteIndex == index,
                        isEditing: editingSlotId == slot.id,
                        onStartEditing: { editingSlotId = slot.id },
                        onEndEditing: { editingSlotId = nil },
                        onRename: { newName in
                            slotManager.renameSlot(at: index, to: newName)
                        },
                        onDelete: {
                            slotManager.removeSlot(at: index)
                        }
                    )
                    .onDrag {
                        draggedSlot = slot
                        return NSItemProvider(object: slot.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: SlotDropDelegate(
                        slot: slot,
                        slotManager: slotManager,
                        draggedSlot: $draggedSlot
                    ))
                }
            }

            // Slot count controls
            HStack {
                Spacer()

                Button(action: {
                    if slotManager.totalSlots > 1 {
                        slotManager.removeSlot(at: slotManager.totalSlots - 1)
                    }
                }) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .disabled(slotManager.totalSlots <= 1)

                Text("\(slotManager.totalSlots)")
                    .monospacedDigit()
                    .frame(minWidth: 24)

                Button(action: { slotManager.addSlot() }) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.top, 4)
        }
        .padding()
        .sheet(isPresented: $showingTemplates) {
            SlotTemplatesView(slotManager: slotManager)
        }
    }
}

struct SlotDropDelegate: DropDelegate {
    let slot: Slot
    let slotManager: SlotManager
    @Binding var draggedSlot: Slot?

    func performDrop(info: DropInfo) -> Bool {
        draggedSlot = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedSlot = draggedSlot,
              draggedSlot.id != slot.id,
              let fromIndex = slotManager.today.slots.firstIndex(where: { $0.id == draggedSlot.id }),
              let toIndex = slotManager.today.slots.firstIndex(where: { $0.id == slot.id }) else {
            return
        }

        withAnimation(.default) {
            slotManager.moveSlot(from: IndexSet(integer: fromIndex), to: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
