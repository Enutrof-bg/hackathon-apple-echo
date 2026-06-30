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

    private let originalTranscript: String?
    private let onSave: (() -> Void)?

    init(memory: EchoMemory, onSave: (() -> Void)? = nil) {
        _title = State(initialValue: memory.title)
        _creator = State(initialValue: memory.creator ?? "")
        _category = State(initialValue: memory.category)
        _emotion = State(initialValue: memory.emotion)
        _memoryText = State(initialValue: memory.memory)
        _echoLine = State(initialValue: memory.echoLine)
        _year = State(initialValue: memory.year ?? "")
        originalTranscript = memory.originalTranscript
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    EchoCardView(memory: previewMemory)

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
                        saveMemory()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var previewMemory: EchoMemory {
        makeMemory()
    }

    private func saveMemory() {
        modelContext.insert(makeMemory())
        try? modelContext.save()
        dismiss()
        onSave?()
    }

    private func makeMemory() -> EchoMemory {
        EchoMemory(
            title: title.isEmpty ? "Untitled Echo" : title,
            creator: creator.nilIfBlank,
            category: category,
            emotion: emotion,
            memory: memoryText.isEmpty ? "A memory I want to keep." : memoryText,
            echoLine: echoLine.isEmpty ? "A memory worth keeping." : echoLine,
            year: year.nilIfBlank,
            originalTranscript: originalTranscript
        )
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    ReviewCardView(
        memory: EchoMemory(
            title: "Spirited Away",
            category: .film,
            emotion: .wonder,
            memory: "I watched it with my sister when we were kids.",
            echoLine: "A childhood memory wrapped in magic and safety."
        )
    )
    .modelContainer(for: EchoMemory.self, inMemory: true)
}
