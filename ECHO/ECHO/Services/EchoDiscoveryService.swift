import Foundation

protocol EchoDiscoverySuggestionProviding {
    func suggestions(existingMemories: [EchoMemory]) -> [EchoDiscoverySuggestion]
}

struct EchoDiscoveryService {
    static let maxQueueItems = 8
    static let maxRediscoverItems = 6
    static let maxSuggestionItems = 6

    private let suggestionProvider: any EchoDiscoverySuggestionProviding

    init(suggestionProvider: any EchoDiscoverySuggestionProviding = HardcodedEchoDiscoverySuggestionProvider()) {
        self.suggestionProvider = suggestionProvider
    }

    func queueItems(from memories: [EchoMemory]) -> [EchoMemory] {
        Array(
            memories
                .filter { $0.deletedAt == nil && $0.discoveryStatus == .notDiscovered }
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(Self.maxQueueItems)
        )
    }

    func rediscoverItems(from memories: [EchoMemory]) -> [EchoMemory] {
        Array(
            memories
                .filter { $0.deletedAt == nil && $0.discoveryStatus == .discovered }
                .sorted { $0.createdAt < $1.createdAt }
                .prefix(Self.maxRediscoverItems)
        )
    }

    func suggestions(existingMemories: [EchoMemory]) -> [EchoDiscoverySuggestion] {
        Array(suggestionProvider.suggestions(existingMemories: existingMemories).prefix(Self.maxSuggestionItems))
    }
}

struct HardcodedEchoDiscoverySuggestionProvider: EchoDiscoverySuggestionProviding {
    func suggestions(existingMemories: [EchoMemory]) -> [EchoDiscoverySuggestion] {
        let existingTitles = Set(existingMemories.map { $0.title.discoveryNormalized })

        return Self.seedSuggestions.filter { suggestion in
            !existingTitles.contains(suggestion.draft.title.discoveryNormalized)
        }
    }

    private static let seedSuggestions: [EchoDiscoverySuggestion] = [
        EchoDiscoverySuggestion(
            draft: EchoMemoryDraft(
                title: "Stalker",
                creator: "Andrei Tarkovsky",
                category: .film,
                emotion: .melancholy,
                memory: "A film to discover for its quiet, haunted journey through desire, faith, and strange landscapes.",
                year: "1979",
                originalTranscript: "Hardcoded Discover suggestion: Stalker by Andrei Tarkovsky.",
                discoveryStatus: .notDiscovered
            ),
            reason: "You seem drawn to solitude, mystery, and slow emotional landscapes.",
            basis: .hardcodedSeed
        ),
        EchoDiscoverySuggestion(
            draft: EchoMemoryDraft(
                title: "Invisible Cities",
                creator: "Italo Calvino",
                category: .book,
                emotion: .curiosity,
                memory: "A book to discover for imagined cities that feel like maps of memory, language, and longing.",
                year: "1972",
                originalTranscript: "Hardcoded Discover suggestion: Invisible Cities by Italo Calvino.",
                discoveryStatus: .notDiscovered
            ),
            reason: "This fits your interest in places, architecture, memory, and fragmented storytelling.",
            basis: .hardcodedSeed
        ),
        EchoDiscoverySuggestion(
            draft: EchoMemoryDraft(
                title: "The Dispossessed",
                creator: "Ursula K. Le Guin",
                category: .book,
                emotion: .curiosity,
                memory: "A book to discover for political imagination, loneliness between worlds, and the cost of belonging nowhere fully.",
                year: "1974",
                originalTranscript: "Hardcoded Discover suggestion: The Dispossessed by Ursula K. Le Guin.",
                discoveryStatus: .notDiscovered
            ),
            reason: "A good match for your curiosity about imagined societies, identity, exile, and belonging.",
            basis: .hardcodedSeed
        ),
        EchoDiscoverySuggestion(
            draft: EchoMemoryDraft(
                title: "Kind of Blue",
                creator: "Miles Davis",
                category: .music,
                emotion: .calm,
                memory: "An album to discover for spacious quiet, blue-hour focus, and music that leaves room to breathe.",
                year: "1959",
                originalTranscript: "Hardcoded Discover suggestion: Kind of Blue by Miles Davis.",
                discoveryStatus: .notDiscovered
            ),
            reason: "For a quieter mood: spacious sound, blue-hour atmosphere, and room to breathe.",
            basis: .hardcodedSeed
        ),
        EchoDiscoverySuggestion(
            draft: EchoMemoryDraft(
                title: "The Garden of Forking Paths",
                creator: "Jorge Luis Borges",
                category: .book,
                emotion: .wonder,
                memory: "A story to discover for labyrinths, time, choice, and the feeling that reality has hidden corridors.",
                year: "1941",
                originalTranscript: "Hardcoded Discover suggestion: The Garden of Forking Paths by Jorge Luis Borges.",
                discoveryStatus: .notDiscovered
            ),
            reason: "If time, memory, and labyrinth-like stories intrigue you, this belongs in the queue.",
            basis: .hardcodedSeed
        ),
        EchoDiscoverySuggestion(
            draft: EchoMemoryDraft(
                title: "Paris, Texas",
                creator: "Wim Wenders",
                category: .film,
                emotion: .melancholy,
                memory: "A film to discover for distance, family, desert light, and the ache of trying to return.",
                year: "1984",
                originalTranscript: "Hardcoded Discover suggestion: Paris, Texas by Wim Wenders.",
                discoveryStatus: .notDiscovered
            ),
            reason: "Recommended for the thread between absence, travel, family ties, and soft melancholy.",
            basis: .hardcodedSeed
        )
    ]
}

private extension String {
    var discoveryNormalized: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
