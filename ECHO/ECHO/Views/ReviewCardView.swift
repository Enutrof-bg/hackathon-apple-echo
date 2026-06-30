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
    @State private var isEditing = false
    @State private var saveError: EchoUserFacingError?

    private let originalTranscript: String?
    private let onSave: (() -> Void)?
    private let persistenceService = EchoMemoryPersistenceService()

    init(draft: EchoMemoryDraft, onSave: (() -> Void)? = nil) {
        _title = State(initialValue: draft.title)
        _creator = State(initialValue: draft.creator ?? "")
        _category = State(initialValue: draft.category)
        _emotion = State(initialValue: draft.emotion)
        _memoryText = State(initialValue: draft.memory)
        _echoLine = State(initialValue: draft.echoLine)
        _year = State(initialValue: draft.year ?? "")
        originalTranscript = draft.originalTranscript
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
                            year: $year
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
                    Button("Save Echo") {
                        saveDraft()
                    }
                    .buttonStyle(.borderedProminent)
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

    private func saveDraft() {
        do {
            try persistenceService.insert(makeDraft(), in: modelContext)
            dismiss()
            onSave?()
        } catch {
            saveError = EchoUserFacingError(message: error.localizedDescription)
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
            originalTranscript: originalTranscript
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
            echoLine: "A childhood memory wrapped in magic and safety."
        )
    )
    .modelContainer(for: EchoMemory.self, inMemory: true)
}
