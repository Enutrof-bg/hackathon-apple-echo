import Foundation

protocol EchoRecommendationProviding {
    func recommendations(for source: EchoMemory, among memories: [EchoMemory]) -> [EchoRecommendation]
}

struct EchoRecommendationService {
    static let maxDisplayedRecommendations = 3
    static let minimumRecommendationScore = 3

    private let provider: any EchoRecommendationProviding

    init(provider: any EchoRecommendationProviding = LocalEchoRecommendationProvider()) {
        self.provider = provider
    }

    func recommendations(for source: EchoMemory, among memories: [EchoMemory]) -> [EchoRecommendation] {
        let recommendations = provider.recommendations(for: source, among: memories)
        return Array(
            recommendations
                .filter { $0.score >= Self.minimumRecommendationScore }
                .sorted {
                    if $0.score == $1.score {
                        return $0.target.createdAt > $1.target.createdAt
                    }
                    return $0.score > $1.score
                }
                .prefix(Self.maxDisplayedRecommendations)
        )
    }
}

struct LocalEchoRecommendationProvider: EchoRecommendationProviding {
    func recommendations(for source: EchoMemory, among memories: [EchoMemory]) -> [EchoRecommendation] {
        memories
            .filter { candidate in
                candidate.id != source.id
                && candidate.deletedAt == nil
                && candidate.discoveryStatus == .notDiscovered
            }
            .compactMap { candidate in
                recommendation(for: source, candidate: candidate)
            }
            .sorted {
                if $0.score == $1.score {
                    return $0.target.createdAt > $1.target.createdAt
                }
                return $0.score > $1.score
            }
    }

    private func recommendation(for source: EchoMemory, candidate: EchoMemory) -> EchoRecommendation? {
        let score = recommendationScore(source: source, candidate: candidate)
        guard score.value > 0 else { return nil }

        return EchoRecommendation(
            target: candidate,
            reason: recommendationReason(source: source, candidate: candidate, basis: score.basis, sharedThemes: score.sharedThemes),
            score: score.value,
            basis: score.basis
        )
    }

    private func recommendationScore(
        source: EchoMemory,
        candidate: EchoMemory
    ) -> (value: Int, basis: EchoRecommendationBasis, sharedThemes: Set<String>) {
        var score = 0
        var basis = EchoRecommendationBasis.discoveryQueue
        let sharedThemes = source.recommendationKeywords.intersection(candidate.recommendationKeywords)

        if source.emotion == candidate.emotion {
            score += 4
            basis = .emotionalFit
        }

        if source.category == candidate.category {
            score += 3
            if basis == .discoveryQueue {
                basis = .sameCategory
            }
        }

        if let sourceCreator = source.creator?.nilIfBlank,
           let candidateCreator = candidate.creator?.nilIfBlank,
           sourceCreator.recommendationToken == candidateCreator.recommendationToken {
            score += 5
            basis = .sharedCreator
        }

        if let sourceYear = source.year?.nilIfBlank,
           let candidateYear = candidate.year?.nilIfBlank,
           sourceYear == candidateYear {
            score += 1
        }

        if !sharedThemes.isEmpty {
            score += min(sharedThemes.count, 4)
            if basis == .discoveryQueue || basis == .sameCategory {
                basis = .sharedTheme
            }
        }

        if candidate.discoveryStatus == .notDiscovered {
            score += 1
        }

        return (score, basis, sharedThemes)
    }

    private func recommendationReason(
        source: EchoMemory,
        candidate: EchoMemory,
        basis: EchoRecommendationBasis,
        sharedThemes: Set<String>
    ) -> String {
        let themePhrase = sharedThemes.recommendationPhrase

        switch basis {
        case .sharedCreator:
            if let creator = candidate.creator?.nilIfBlank {
                return "A not-yet-discovered Echo connected through \(creator)."
            }
            return "A not-yet-discovered Echo connected by creator details."
        case .emotionalFit:
            if let themePhrase {
                return "You may want this next because it carries \(source.emotion.title.lowercased()) around \(themePhrase)."
            }
            return "You may want this next because it carries a similar emotional tone: \(source.emotion.title.lowercased())."
        case .sameCategory:
            return "A \(candidate.category.title.lowercased()) still waiting in your discovery queue."
        case .sharedTheme:
            if let themePhrase {
                return "Recommended because both Echoes circle around \(themePhrase)."
            }
            return "Recommended because it seems close to the same personal themes."
        case .discoveryQueue:
            return "A not-yet-discovered Echo that may fit this part of your archive."
        }
    }
}

private extension EchoMemory {
    var recommendationKeywords: Set<String> {
        Set((title + " " + memory)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.recommendationToken }
            .compactMap { token in
                guard let token, token.count >= 4, !Self.recommendationStopwords.contains(token) else { return nil }
                return token
            })
    }

    static let recommendationStopwords: Set<String> = [
        "about", "after", "again", "also", "because", "been", "both", "came", "could", "echo", "even",
        "felt", "first", "from", "have", "inside", "into", "just", "keep", "made", "memory", "more", "over",
        "still", "that", "their", "them", "then", "there", "these", "they", "this", "time", "want",
        "watched", "were", "when", "with", "would", "your", "dans", "avec", "pour", "comme", "plus",
        "encore", "souvenir", "veux", "lire", "voir", "regarder"
    ]
}

private extension Set where Element == String {
    var recommendationPhrase: String? {
        let terms = sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs < rhs
            }
            return lhs.count > rhs.count
        }
        .prefix(3)

        guard !terms.isEmpty else { return nil }
        return terms.joined(separator: ", ")
    }
}

private extension String {
    var recommendationToken: String? {
        let token = folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return token.isEmpty ? nil : token
    }
}
