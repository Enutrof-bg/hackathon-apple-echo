import Foundation

protocol EchoCardPresentable {
    var title: String { get }
    var creator: String? { get }
    var category: EchoCategory { get }
    var emotion: EchoEmotion { get }
    var memory: String { get }
    var echoLine: String { get }
    var year: String? { get }
    var originalTranscript: String? { get }
    var discoveryStatus: EchoDiscoveryStatus { get }
}

struct EchoMemoryDraft: Identifiable, Equatable, EchoCardPresentable {
    var id: UUID
    var title: String
    var creator: String?
    var category: EchoCategory
    var emotion: EchoEmotion
    var memory: String
    var echoLine: String
    var year: String?
    var originalTranscript: String?
    var discoveryStatus: EchoDiscoveryStatus

    init(
        id: UUID = UUID(),
        title: String,
        creator: String? = nil,
        category: EchoCategory,
        emotion: EchoEmotion,
        memory: String,
        echoLine: String,
        year: String? = nil,
        originalTranscript: String? = nil,
        discoveryStatus: EchoDiscoveryStatus = .discovered
    ) {
        self.id = id
        self.title = title
        self.creator = creator
        self.category = category
        self.emotion = emotion
        self.memory = memory
        self.echoLine = echoLine
        self.year = year
        self.originalTranscript = originalTranscript
        self.discoveryStatus = discoveryStatus
    }

    init(memory: EchoMemory) {
        self.id = memory.id
        self.title = memory.title
        self.creator = memory.creator
        self.category = memory.category
        self.emotion = memory.emotion
        self.memory = memory.memory
        self.echoLine = memory.echoLine
        self.year = memory.year
        self.originalTranscript = memory.originalTranscript
        self.discoveryStatus = memory.discoveryStatus
    }

    var sanitized: EchoMemoryDraft {
        EchoMemoryDraft(
            id: id,
            title: title.trimmedFallback("Untitled Echo"),
            creator: creator?.nilIfBlank,
            category: category,
            emotion: emotion,
            memory: memory.trimmedFallback("A memory I want to keep."),
            echoLine: echoLine.trimmedFallback("A memory worth keeping."),
            year: year?.nilIfBlank,
            originalTranscript: originalTranscript?.nilIfBlank,
            discoveryStatus: discoveryStatus
        )
    }

    func makePersistedMemory(createdAt: Date = Date()) -> EchoMemory {
        let draft = sanitized
        return EchoMemory(
            title: draft.title,
            creator: draft.creator,
            category: draft.category,
            emotion: draft.emotion,
            memory: draft.memory,
            echoLine: draft.echoLine,
            year: draft.year,
            originalTranscript: draft.originalTranscript,
            discoveryStatus: draft.discoveryStatus,
            createdAt: createdAt
        )
    }
}

extension EchoMemory: EchoCardPresentable {}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func trimmedFallback(_ fallback: String) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
