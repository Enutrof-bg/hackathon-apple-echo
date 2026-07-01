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
    @State private var year: String
    @State private var discoveryStatus: EchoDiscoveryStatus
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var didSave = false
    @State private var saveError: EchoUserFacingError?

    private let originalTranscript: String?
    private let audioFileName: String?
    private let audioDuration: TimeInterval?
    private let existingMemories: [EchoMemory]
    private let onSave: (() -> Void)?
    private let persistenceService = EchoMemoryPersistenceService()
    private let linkService = EchoMemoryLinkService()

    init(
        draft: EchoMemoryDraft,
        existingMemories: [EchoMemory] = [],
        startsEditing: Bool = false,
        onSave: (() -> Void)? = nil
    ) {
        _title = State(initialValue: draft.title)
        _creator = State(initialValue: draft.creator ?? "")
        _category = State(initialValue: draft.category)
        _emotion = State(initialValue: draft.emotion)
        _memoryText = State(initialValue: draft.memory)
        _year = State(initialValue: draft.year ?? "")
        _discoveryStatus = State(initialValue: draft.discoveryStatus)
        _isEditing = State(initialValue: startsEditing)
        originalTranscript = draft.originalTranscript
        audioFileName = draft.audioFileName
        audioDuration = draft.audioDuration
        self.existingMemories = existingMemories
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Extracted Observation")
                            .echoSectionTitle()

                        EchoCardView(memory: previewDraft)
                    }

                    if isEditing {
                        EchoFormView(
                            title: $title,
                            creator: $creator,
                            category: $category,
                            emotion: $emotion,
                            memoryText: $memoryText,
                            year: $year,
                            discoveryStatus: $discoveryStatus
                        )
                    }
                }
                .padding(20)
            }
            .background(EchoStyle.background)
            .navigationTitle("Review Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        discardDraft()
                    }
                    .accessibilityHint("Double tap to close this draft without saving it.")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? "Done" : "Edit") {
                        isEditing.toggle()
                    }
                    .accessibilityLabel(isEditing ? "Done editing" : "Edit draft")
                    .accessibilityHint(isEditing ? "Double tap to return to the card preview." : "Double tap to edit the extracted card fields.")
                }

                ToolbarItem(placement: .bottomBar) {
                    Button(isSaving ? "Saving..." : "Save Echo") {
                        Task {
                            await saveDraft()
                        }
                    }
                    .echoGlassButtonStyle(prominent: true)
                    .disabled(isSaving)
                    .accessibilityLabel(isSaving ? "Saving Echo" : "Save Echo")
                    .accessibilityHint("Double tap to save this reviewed Echo to your archive.")
                }
            }
            .alert(item: $saveError) { error in
                Alert(
                    title: Text("Echo could not be saved"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onDisappear {
                cleanupDiscardedAudioIfNeeded()
            }
        }
    }

    private var previewDraft: EchoMemoryDraft {
        makeDraft()
    }

    private func discardDraft() {
        cleanupDiscardedAudioIfNeeded()
        dismiss()
    }

    private func cleanupDiscardedAudioIfNeeded() {
        guard !didSave else { return }
        EchoAudioFileService.deleteRecording(fileName: audioFileName)
    }

    private func saveDraft() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let savedMemory = try persistenceService.insert(makeDraft(), in: modelContext)
            didSave = true
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
            year: year.nilIfBlank,
            originalTranscript: originalTranscript,
            audioFileName: audioFileName,
            audioDuration: audioDuration,
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
            memory: "I watched it with my sister when we were kids."
        )
    )
    .modelContainer(for: [EchoMemory.self, EchoMemoryStoredLink.self], inMemory: true)
}
