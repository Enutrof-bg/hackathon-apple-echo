import Foundation

struct EchoSearchService {
    func search(_ memories: [EchoMemory], query: String) -> [EchoMemory] {
        let intent = EchoSearchIntent(query: query)
        guard !intent.isEmpty else { return memories }

        return memories
            .map { memory in
                ScoredEchoMemory(memory: memory, score: score(memory, for: intent))
            }
            .filter { $0.score > 0 }
            .sorted { first, second in
                if first.score == second.score {
                    return first.memory.createdAt > second.memory.createdAt
                }
                return first.score > second.score
            }
            .map(\.memory)
    }

    private func score(_ memory: EchoMemory, for intent: EchoSearchIntent) -> Int {
        var score = 0
        let title = memory.title.searchNormalized
        let creator = memory.creator?.searchNormalized ?? ""
        let category = memory.category.title.searchNormalized
        let emotion = memory.emotion.title.searchNormalized
        let status = memory.discoveryStatus.searchTerms.joined(separator: " ").searchNormalized
        let year = memory.year?.searchNormalized ?? ""
        let memoryText = memory.memory.searchNormalized
        let echoLine = memory.echoLine.searchNormalized
        let fullText = [title, creator, category, emotion, status, year, memoryText, echoLine]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if let categoryFilter = intent.category {
            if memory.category == categoryFilter {
                score += 12
            } else {
                score -= 8
            }
        }

        if let emotionFilter = intent.emotion {
            if memory.emotion == emotionFilter {
                score += 10
            } else {
                score -= 4
            }
        }

        if let statusFilter = intent.discoveryStatus {
            if memory.discoveryStatus == statusFilter {
                score += 12
            } else {
                score -= 8
            }
        }

        if let yearFilter = intent.year {
            if year == yearFilter {
                score += 8
            } else {
                score -= 2
            }
        }

        for term in intent.terms {
            if title.contains(term) {
                score += 10
            }
            if creator.contains(term) {
                score += 8
            }
            if category.contains(term) || emotion.contains(term) || status.contains(term) || year.contains(term) {
                score += 5
            }
            if memoryText.contains(term) {
                score += 4
            }
            if echoLine.contains(term) {
                score += 3
            }
            if fullText.contains(term) {
                score += 1
            }
        }

        for theme in intent.themes {
            if fullText.contains(theme) {
                score += 4
            }
        }

        return score
    }
}

private struct ScoredEchoMemory {
    let memory: EchoMemory
    let score: Int
}

private struct EchoSearchIntent {
    let rawQuery: String
    let normalizedQuery: String
    let category: EchoCategory?
    let emotion: EchoEmotion?
    let discoveryStatus: EchoDiscoveryStatus?
    let year: String?
    let terms: [String]
    let themes: [String]

    var isEmpty: Bool {
        normalizedQuery.isEmpty
    }

    init(query: String) {
        rawQuery = query
        normalizedQuery = query.searchNormalized
        category = Self.detectCategory(in: normalizedQuery)
        emotion = Self.detectEmotion(in: normalizedQuery)
        discoveryStatus = Self.detectDiscoveryStatus(in: normalizedQuery)
        year = Self.detectYear(in: normalizedQuery)
        themes = Self.detectThemes(in: normalizedQuery)
        terms = Self.searchTerms(from: normalizedQuery)
    }

    private static func detectCategory(in query: String) -> EchoCategory? {
        let matches: [(EchoCategory, [String])] = [
            (.film, ["film", "films", "movie", "movies", "cinema", "watch", "watched", "voir", "regarder", "vu"]),
            (.book, ["book", "books", "novel", "read", "reading", "livre", "livres", "roman", "lire", "lu", "lis"]),
            (.music, ["music", "song", "songs", "album", "track", "listen", "musique", "chanson", "album", "ecouter", "ecoute"]),
            (.painting, ["painting", "paintings", "museum", "gallery", "peinture", "musee", "galerie", "tableau"]),
            (.videoGame, ["game", "games", "videogame", "play", "played", "jeu", "jeux", "jouer"]),
            (.performance, ["show", "concert", "theater", "theatre", "stage", "performance", "spectacle", "scene"]),
            (.place, ["place", "city", "street", "park", "visit", "visited", "lieu", "ville", "rue", "parc", "visiter"]),
            (.object, ["object", "objects", "toy", "gift", "photo", "objet", "jouet", "cadeau"])
        ]

        return matches.first { _, keywords in
            keywords.contains { query.containsWholeSearchTerm($0) }
        }?.0
    }

    private static func detectEmotion(in query: String) -> EchoEmotion? {
        let matches: [(EchoEmotion, [String])] = [
            (.nostalgia, ["nostalgia", "nostalgic", "childhood", "souvenir", "enfance", "nostalgie", "nostalgique"]),
            (.joy, ["joy", "happy", "happiness", "fun", "laugh", "joie", "joyeux", "heureux", "rire"]),
            (.wonder, ["wonder", "amazed", "magic", "beautiful", "wonderful", "emerveille", "merveille", "magique", "beau"]),
            (.melancholy, ["melancholy", "sad", "sadness", "lonely", "loneliness", "triste", "tristesse", "solitude", "seul", "melancolie"]),
            (.calm, ["calm", "quiet", "peace", "safe", "calme", "paix", "silence", "doux"]),
            (.shock, ["shock", "scared", "fear", "intense", "surprised", "choc", "peur", "intense", "surprise"]),
            (.love, ["love", "family", "friend", "closeness", "amour", "famille", "ami", "frere", "soeur", "proche"]),
            (.curiosity, ["curiosity", "curious", "discover", "question", "strange", "curiosite", "curieux", "decouvrir", "etrange"])
        ]

        return matches.first { _, keywords in
            keywords.contains { query.containsWholeSearchTerm($0) }
        }?.0
    }

    private static func detectDiscoveryStatus(in query: String) -> EchoDiscoveryStatus? {
        let notDiscoveredPhrases = [
            "not discovered", "not yet", "to discover", "want to", "would like", "watchlist", "reading list",
            "pas encore", "pas decouvert", "a decouvrir", "je veux", "j aimerais", "j aimerai", "je voudrais", "liste"
        ]
        if notDiscoveredPhrases.contains(where: { query.contains($0) }) {
            return .notDiscovered
        }

        let discoveredPhrases = [
            "discovered", "already", "i read", "i watched", "i listened", "j ai lu", "j ai vu", "deja", "decouvert"
        ]
        if discoveredPhrases.contains(where: { query.contains($0) }) {
            return .discovered
        }

        return nil
    }

    private static func detectYear(in query: String) -> String? {
        guard let range = query.range(of: #"\b(19|20)\d{2}\b"#, options: .regularExpression) else { return nil }
        return String(query[range])
    }

    private static func detectThemes(in query: String) -> [String] {
        let themeMap: [(String, [String])] = [
            ("winter", ["winter", "hiver", "neige", "snow"]),
            ("family", ["family", "famille", "frere", "soeur", "parent"]),
            ("lonely", ["lonely", "loneliness", "solitude", "seul"]),
            ("rain", ["rain", "pluie"]),
            ("city", ["city", "ville", "street", "rue"]),
            ("memory", ["memory", "souvenir"]),
            ("future", ["future", "avenir"])
        ]

        return themeMap.compactMap { theme, aliases in
            aliases.contains { query.containsWholeSearchTerm($0) } ? theme : nil
        }
    }

    private static func searchTerms(from query: String) -> [String] {
        query
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.searchNormalized }
            .filter { !$0.isEmpty && $0.count >= 3 && !Self.stopwords.contains($0) }
    }

    private static let stopwords: Set<String> = [
        "the", "and", "for", "with", "that", "this", "from", "what", "dans", "avec", "pour", "qui", "que",
        "les", "des", "une", "mon", "mes", "sur", "pas", "encore", "veux", "voudrais", "aimerais", "aimerai"
    ]
}

private extension EchoDiscoveryStatus {
    var searchTerms: [String] {
        switch self {
        case .discovered:
            return ["discovered", "already discovered", "decouvert", "deja decouvert"]
        case .notDiscovered:
            return ["not discovered", "not yet discovered", "a decouvrir", "pas encore decouvert", "watchlist", "reading list"]
        }
    }
}

private extension String {
    var searchNormalized: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "’", with: " ")
            .replacingOccurrences(of: "'", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func containsWholeSearchTerm(_ term: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: term.searchNormalized)
        return range(of: #"\b"# + escaped + #"\b"#, options: .regularExpression) != nil
    }
}
