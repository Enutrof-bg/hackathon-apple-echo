import SwiftData
import SwiftUI

struct EditEchoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let memory: EchoMemory

    @State private var title: String
    @State private var creator: String
    @State private var category: EchoCategory
    @State private var emotion: EchoEmotion
    @State private var memoryText: String
    @State private var echoLine: String
    @State private var year: String

    init(memory: EchoMemory) {
        self.memory = memory
        _title = State(initialValue: memory.title)
        _creator = State(initialValue: memory.creator ?? "")
        _category = State(initialValue: memory.category)
        _emotion = State(initialValue: memory.emotion)
        _memoryText = State(initialValue: memory.memory)
        _echoLine = State(initialValue: memory.echoLine)
        _year = State(initialValue: memory.year ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                EchoFormView(
                    title: $title,
                    creator: $creator,
                    category: $category,
                    emotion: $emotion,
                    memoryText: $memoryText,
                    echoLine: $echoLine,
                    year: $year
                )
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Echo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        applyChanges()
                        dismiss()
                    }
                }
            }
        }
    }

    private func applyChanges() {
        memory.title = title.isEmpty ? "Untitled Echo" : title
        memory.creator = creator.nilIfBlank
        memory.category = category
        memory.emotion = emotion
        memory.memory = memoryText.isEmpty ? "A memory I want to keep." : memoryText
        memory.echoLine = echoLine.isEmpty ? "A memory worth keeping." : echoLine
        memory.year = year.nilIfBlank
        try? modelContext.save()
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
