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
                echoLine: "Stalker is suggested as a quiet film to explore for mystery, faith, and emotional solitude.",
                year: "1979",
                originalTranscript: "Hardcoded Discover suggestion: Stalker by Andrei Tarkovsky.",
                discoveryStatus: .notDiscovered
            ),
            reason: "For Echoes that orbit solitude, mystery, and slow emotional landscapes.",
            basis: .hardcodedSeed
        ),
        EchoDiscoverySuggestion(
            draft: EchoMemoryDraft(
                title: "Invisible Cities",
                creator: "Italo Calvino",
                category: .book,
                emotion: .curiosity,
                memory: "A book to discover for imagined cities that feel like maps of memory, language, and longing.",
                echoLine: "Invisible Cities is suggested for imagined places, memory, language, and poetic urban fragments.",
                year: "1972",
                originalTranscript: "Hardcoded Discover suggestion: Invisible Cities by Italo Calvino.",
                discoveryStatus: .notDiscovered
            ),
            reason: "For users drawn to places, architecture, memory, and poetic fragments.",
            basis: .hardcodedSeed
        ),
        EchoDiscoverySuggestion(
            draft: EchoMemoryDraft(
                title: "The Dispossessed",
                creator: "Ursula K. Le Guin",
                category: .book,
                emotion: .curiosity,
                memory: "A book to discover for political imagination, loneliness between worlds, and the cost of belonging nowhere fully.",
                echoLine: "The Dispossessed is suggested for political imagination, exile, belonging, and difficult hope.",
                year: "1974",
                originalTranscript: "Hardcoded Discover suggestion: The Dispossessed by Ursula K. Le Guin.",
                discoveryStatus: .notDiscovered
            ),
            reason: "For Echoes about worlds that change how people understand society and selfhood.",
            basis: .hardcodedSeed
        ),
        EchoDiscoverySuggestion(
            draft: EchoMemoryDraft(
                title: "Kind of Blue",
                creator: "Miles Davis",
                category: .music,
                emotion: .calm,
                memory: "An album to discover for spacious quiet, blue-hour focus, and music that leaves room to breathe.",
                echoLine: "Kind of Blue is suggested for calm focus, spacious sound, and blue-hour atmosphere.",
                year: "1959",
                originalTranscript: "Hardcoded Discover suggestion: Kind of Blue by Miles Davis.",
                discoveryStatus: .notDiscovered
            ),
            reason: "For moments that need quiet, atmosphere, and emotional spaciousness.",
            basis: .hardcodedSeed
        ),
        EchoDiscoverySuggestion(
            draft: EchoMemoryDraft(
                title: "The Garden of Forking Paths",
                creator: "Jorge Luis Borges",
                category: .book,
                emotion: .wonder,
                memory: "A story to discover for labyrinths, time, choice, and the feeling that reality has hidden corridors.",
                echoLine: "The Garden of Forking Paths is suggested for labyrinths, time, choice, and intellectual wonder.",
                year: "1941",
                originalTranscript: "Hardcoded Discover suggestion: The Garden of Forking Paths by Jorge Luis Borges.",
                discoveryStatus: .notDiscovered
            ),
            reason: "For Echoes around puzzles, memory, time, and strange intellectual wonder.",
            basis: .hardcodedSeed
        ),
        EchoDiscoverySuggestion(
            draft: EchoMemoryDraft(
                title: "Paris, Texas",
                creator: "Wim Wenders",
                category: .film,
                emotion: .melancholy,
                memory: "A film to discover for distance, family, desert light, and the ache of trying to return.",
                echoLine: "Paris, Texas is suggested for distance, family, desert light, and fragile repair.",
                year: "1984",
                originalTranscript: "Hardcoded Discover suggestion: Paris, Texas by Wim Wenders.",
                discoveryStatus: .notDiscovered
            ),
            reason: "For Echoes shaped by absence, travel, family, and soft melancholy.",
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
