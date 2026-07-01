import SwiftData
import SwiftUI

struct ReviewCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var creator: String
    @State private var category: EchoCategory
    @State private var emotion: EchoEmotion
    @State private var memoryText: String
    @State private var echoLine: String
    @State private var year: String
    @State private var discoveryStatus: EchoDiscoveryStatus
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var saveError: EchoUserFacingError?

    private let originalTranscript: String?
    private let existingMemories: [EchoMemory]
    private let onSave: (() -> Void)?
    private let persistenceService = EchoMemoryPersistenceService()
    private let linkService = EchoMemoryLinkService()

    init(draft: EchoMemoryDraft, existingMemories: [EchoMemory] = [], onSave: (() -> Void)? = nil) {
        _title = State(initialValue: draft.title)
        _creator = State(initialValue: draft.creator ?? "")
        _category = State(initialValue: draft.category)
        _emotion = State(initialValue: draft.emotion)
        _memoryText = State(initialValue: draft.memory)
        _echoLine = State(initialValue: draft.echoLine)
        _year = State(initialValue: draft.year ?? "")
        _discoveryStatus = State(initialValue: draft.discoveryStatus)
        originalTranscript = draft.originalTranscript
        self.existingMemories = existingMemories
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    EchoCardView(memory: previewDraft)

                    if isEditing {
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
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Review Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? "Done" : "Edit") {
                        isEditing.toggle()
                    }
                }

                ToolbarItem(placement: .bottomBar) {
                    Button(isSaving ? "Saving..." : "Save Echo") {
                        Task {
                            await saveDraft()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving)
                }
            }
            .alert(item: $saveError) { error in
                Alert(
                    title: Text("Echo could not be saved"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var previewDraft: EchoMemoryDraft {
        makeDraft().sanitized
    }

    private func saveDraft() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let savedMemory = try persistenceService.insert(makeDraft(), in: modelContext)
            try? linkService.createAndStoreLinks(for: savedMemory, among: existingMemories, in: modelContext)
            dismiss()
            onSave?()
        } catch {
            saveError = .persistenceFailure(action: "save this Echo")
        }
    }

    private func makeDraft() -> EchoMemoryDraft {
        EchoMemoryDraft(
            title: title,
            creator: creator.nilIfBlank,
            category: category,
            emotion: emotion,
            memory: memoryText,
            echoLine: echoLine,
            year: year.nilIfBlank,
            originalTranscript: originalTranscript,
            discoveryStatus: discoveryStatus
        )
    }
}

#Preview {
    ReviewCardView(
        draft: EchoMemoryDraft(
            title: "Spirited Away",
            category: .film,
            emotion: .wonder,
            memory: "I watched it with my sister when we were kids.",
            echoLine: "Spirited Away reminds me of watching a magical film with my sister as a child."
        )
    )
    .modelContainer(for: [EchoMemory.self, EchoMemoryStoredLink.self], inMemory: true)
}
