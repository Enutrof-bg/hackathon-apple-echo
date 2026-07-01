import SwiftData
import SwiftUI

struct EditEchoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let memory: EchoMemory
    let candidateMemories: [EchoMemory]

    @State private var title: String
    @State private var creator: String
    @State private var category: EchoCategory
    @State private var emotion: EchoEmotion
    @State private var memoryText: String
    @State private var echoLine: String
    @State private var year: String
    @State private var discoveryStatus: EchoDiscoveryStatus
    @State private var isSaving = false
    @State private var saveError: EchoUserFacingError?

    private let persistenceService = EchoMemoryPersistenceService()
    private let linkService = EchoMemoryLinkService()

    init(memory: EchoMemory, candidateMemories: [EchoMemory] = []) {
        self.memory = memory
        self.candidateMemories = candidateMemories
        _title = State(initialValue: memory.title)
        _creator = State(initialValue: memory.creator ?? "")
        _category = State(initialValue: memory.category)
        _emotion = State(initialValue: memory.emotion)
        _memoryText = State(initialValue: memory.memory)
        _echoLine = State(initialValue: memory.echoLine)
        _year = State(initialValue: memory.year ?? "")
        _discoveryStatus = State(initialValue: memory.discoveryStatus)
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
                    year: $year,
                    discoveryStatus: $discoveryStatus
                )
                .padding(20)
            }
            .background(EchoStyle.background)
            .navigationTitle("Edit Echo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        Task {
                            await saveChanges()
                        }
                    }
                    .disabled(isSaving)
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

    private func saveChanges() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try persistenceService.update(memory, with: draft, in: modelContext)
            try? linkService.refreshStoredLinks(for: memory, among: candidateMemories, in: modelContext)
            dismiss()
        } catch {
            saveError = .persistenceFailure(action: "update this Echo")
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
            originalTranscript: memory.originalTranscript,
            discoveryStatus: discoveryStatus
        )
    }
}
