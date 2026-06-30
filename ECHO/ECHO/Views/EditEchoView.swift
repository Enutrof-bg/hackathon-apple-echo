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
    @State private var saveError: EchoUserFacingError?

    private let persistenceService = EchoMemoryPersistenceService()

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
                        saveChanges()
                    }
                }
            }
            .alert(item: $saveError) { error in
                Alert(
                    title: Text("Echo could not be updated"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func saveChanges() {
        do {
            try persistenceService.update(memory, with: draft, in: modelContext)
            dismiss()
        } catch {
            saveError = EchoUserFacingError(message: error.localizedDescription)
        }
    }

    private var draft: EchoMemoryDraft {
        EchoMemoryDraft(
            id: memory.id,
            title: title,
            creator: creator.nilIfBlank,
            category: category,
            emotion: emotion,
            memory: memoryText,
            echoLine: echoLine,
            year: year.nilIfBlank,
            originalTranscript: memory.originalTranscript
        )
    }
}
