import SwiftUI

struct SlotTemplatesView: View {
    @ObservedObject var slotManager: SlotManager
    @Environment(\.dismiss) private var dismiss
    @State private var editingIndex: Int?
    @State private var editText: String = ""
    @FocusState private var isFocused: Bool

    // Placeholder prompting state
    @State private var showingPlaceholderPrompt = false
    @State private var placeholdersToFill: [String] = []
    @State private var currentPlaceholderIndex = 0
    @State private var placeholderReplacements: [String: String] = [:]
    @State private var currentPlaceholderValue: String = ""

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Default Templates")
                    .font(.headline)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.plain)
            }

            Text("These names will be used when starting a new day.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Default slot count
            HStack {
                Text("Default slots per day:")
                    .font(.subheadline)

                Spacer()

                Stepper("\(slotManager.defaultSlotCount)", value: Binding(
                    get: { slotManager.defaultSlotCount },
                    set: { slotManager.setDefaultSlotCount($0) }
                ), in: 1...30)
                .frame(width: 100)
            }
            .padding(.vertical, 4)

            Divider()

            // Template list
            List {
                ForEach(0..<slotManager.defaultSlotNames.count, id: \.self) { index in
                    HStack {
                        Text("\(index + 1).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 20, alignment: .trailing)

                        if editingIndex == index {
                            TextField("Template name", text: $editText)
                                .textFieldStyle(.plain)
                                .focused($isFocused)
                                .onSubmit {
                                    slotManager.updateDefaultTemplate(at: index, to: editText)
                                    editingIndex = nil
                                }
                                .onAppear {
                                    editText = slotManager.defaultSlotNames[index]
                                    isFocused = true
                                }
                        } else {
                            Text(slotManager.defaultSlotNames[index])
                                .onTapGesture(count: 2) {
                                    editingIndex = index
                                }

                            Spacer()

                            Button(action: {
                                editingIndex = index
                            }) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.plain)
            .frame(maxHeight: 200)

            // Apply to today button
            Button(action: {
                applyTemplates()
            }) {
                Text("Apply Templates to Today")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .help("Replace today's slots with these templates (clears completions)")
        }
        .padding()
        .frame(width: 280, height: 380)
        .sheet(isPresented: $showingPlaceholderPrompt) {
            PlaceholderPromptView(
                placeholder: placeholdersToFill.indices.contains(currentPlaceholderIndex)
                    ? placeholdersToFill[currentPlaceholderIndex] : "",
                value: $currentPlaceholderValue,
                onSubmit: { submitPlaceholderValue() },
                onCancel: { cancelPlaceholderPrompt() }
            )
        }
    }

    private func applyTemplates() {
        let placeholders = slotManager.getTemplatePlaceholders()
        if placeholders.isEmpty {
            // No placeholders, apply directly
            slotManager.initializeNewDay(force: true)
            dismiss()
        } else {
            // Start placeholder prompting
            placeholdersToFill = placeholders
            currentPlaceholderIndex = 0
            placeholderReplacements = [:]
            currentPlaceholderValue = ""
            showingPlaceholderPrompt = true
        }
    }

    private func submitPlaceholderValue() {
        let placeholder = placeholdersToFill[currentPlaceholderIndex]
        placeholderReplacements[placeholder] = currentPlaceholderValue

        currentPlaceholderIndex += 1
        currentPlaceholderValue = ""

        if currentPlaceholderIndex >= placeholdersToFill.count {
            // All placeholders filled, apply template
            showingPlaceholderPrompt = false
            slotManager.applyTemplateWithReplacements(placeholderReplacements)
            dismiss()
        }
    }

    private func cancelPlaceholderPrompt() {
        showingPlaceholderPrompt = false
        placeholdersToFill = []
        currentPlaceholderIndex = 0
        placeholderReplacements = [:]
        currentPlaceholderValue = ""
    }
}

// MARK: - Placeholder Prompt View

struct PlaceholderPromptView: View {
    let placeholder: String
    @Binding var value: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Fill in placeholder")
                .font(.headline)

            Text("Enter a value for:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("[\(placeholder)]")
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)

            TextField("Value", text: $value)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit { onSubmit() }

            HStack(spacing: 12) {
                Button("Cancel") { onCancel() }
                    .buttonStyle(.bordered)

                Button("Next") { onSubmit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(value.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 280)
        .onAppear { isFocused = true }
    }
}
