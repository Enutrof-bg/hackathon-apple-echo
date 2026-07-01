import Foundation
import FoundationModels
import SwiftData

struct EchoMemoryLinkService {
    static let maxStoredLinksPerEcho = 10
    static let maxDisplayedLinks = 5
    static let minimumDisplayedScore = 3

    func createAndStoreLinks(for source: EchoMemory, among memories: [EchoMemory], in modelContext: ModelContext) throws {
        let links = localSuggestedLinks(for: source, among: memories)
        try store(links, for: source, in: modelContext)
    }

    func refreshStoredLinks(for source: EchoMemory, among memories: [EchoMemory], in modelContext: ModelContext) throws {
        try deleteStoredLinks(relatedTo: source.id, in: modelContext, save: false)
        let links = localSuggestedLinks(for: source, among: memories)
        try store(links, for: source, in: modelContext, save: false)
        try modelContext.save()
    }

    func rebuildStoredLinks(for memories: [EchoMemory], in modelContext: ModelContext) throws {
        let activeMemories = memories.filter { $0.deletedAt == nil }
        let storedLinks = try modelContext.fetch(FetchDescriptor<EchoMemoryStoredLink>())

        for storedLink in storedLinks {
            modelContext.delete(storedLink)
        }

        for memory in activeMemories {
            let candidates = activeMemories.filter { $0.id != memory.id }
            let links = localSuggestedLinks(for: memory, among: candidates)
            try store(links, for: memory, in: modelContext, save: false)
        }

        try enforceStoredLinkLimit(for: Set(activeMemories.map(\.id)), in: modelContext)
        try modelContext.save()
    }

    func deleteStoredLinks(relatedTo memoryID: UUID, in modelContext: ModelContext, save: Bool = true) throws {
        let storedLinks = try modelContext.fetch(FetchDescriptor<EchoMemoryStoredLink>())
        let relatedLinks = storedLinks.filter { $0.sourceMemoryID == memoryID || $0.targetMemoryID == memoryID }

        for storedLink in relatedLinks {
            modelContext.delete(storedLink)
        }

        if save {
            try modelContext.save()
        }
    }

    func storedLinks(for source: EchoMemory, among memories: [EchoMemory], storedLinks: [EchoMemoryStoredLink]) -> [EchoMemoryLink] {
        let memoryByID = Dictionary(uniqueKeysWithValues: memories.map { ($0.id, $0) })

        return storedLinks
            .filter { $0.sourceMemoryID == source.id || $0.targetMemoryID == source.id }
            .sorted {
                if $0.score == $1.score {
                    return $0.createdAt > $1.createdAt
                }
                return $0.score > $1.score
            }
            .compactMap { storedLink in
                let targetID = storedLink.sourceMemoryID == source.id ? storedLink.targetMemoryID : storedLink.sourceMemoryID
                guard let target = memoryByID[targetID], target.deletedAt == nil else { return nil }

                return EchoMemoryLink(
                    target: target,
                    basis: storedLink.basis,
                    reason: storedLink.reason,
                    confidence: storedLink.confidence,
                    score: storedLink.score
                )
            }
    }

    func displayedLinks(from links: [EchoMemoryLink]) -> [EchoMemoryLink] {
        Array(
            links
                .filter { $0.score >= Self.minimumDisplayedScore }
                .sorted {
                    if $0.score == $1.score {
                        return $0.target.createdAt > $1.target.createdAt
                    }
                    return $0.score > $1.score
                }
                .prefix(Self.maxDisplayedLinks)
        )
    }

    func localSuggestedLinks(for source: EchoMemory, among memories: [EchoMemory]) -> [EchoMemoryLink] {
        let candidates = memories
            .filter { $0.id != source.id && $0.deletedAt == nil }

        return Array(localLinks(for: source, among: candidates).prefix(Self.maxStoredLinksPerEcho))
    }

    func suggestedLinks(for source: EchoMemory, among memories: [EchoMemory]) async -> [EchoMemoryLink] {
        let candidates = memories
            .filter { $0.id != source.id && $0.deletedAt == nil }

        guard !candidates.isEmpty else { return [] }

        let heuristicLinks = localLinks(for: source, among: candidates)

        do {
            let modelLinks = try await foundationModelLinks(for: source, candidates: Array(candidates.prefix(12)))
            let mergedLinks = merge(modelLinks, with: heuristicLinks)
            return Array(mergedLinks.prefix(Self.maxStoredLinksPerEcho))
        } catch {
            return Array(heuristicLinks.prefix(Self.maxStoredLinksPerEcho))
        }
    }

    private func localLinks(for source: EchoMemory, among candidates: [EchoMemory]) -> [EchoMemoryLink] {
        candidates
            .compactMap { candidate -> ScoredLink? in
                let score = localScore(source: source, candidate: candidate)
                guard score.value > 0 else { return nil }

                return ScoredLink(
                    link: EchoMemoryLink(
                        target: candidate,
                        basis: score.basis,
                        reason: score.reason,
                        confidence: score.value >= 4 ? .high : .medium,
                        score: score.value
                    ),
                    score: score.value
                )
            }
            .sorted { $0.score > $1.score }
            .map(\.link)
    }

    private func localScore(source: EchoMemory, candidate: EchoMemory) -> (value: Int, basis: EchoMemoryLinkBasis, reason: String) {
        var score = 0
        var basis = EchoMemoryLinkBasis.memoryTheme
        var facts: [String] = []

        let sharedKeywords = source.linkKeywords.intersection(candidate.linkKeywords)
        let keywordPhrase = sharedKeywords.linkPhrase

        if source.emotion == candidate.emotion {
            score += 3
            basis = .emotion
        }

        if source.category == candidate.category {
            score += 1
            facts.append("both are \(source.category.title.lowercased()) Echoes")
        }

        if let sourceCreator = source.creator?.nilIfBlank,
           let candidateCreator = candidate.creator?.nilIfBlank,
           sourceCreator.cleanLinkToken == candidateCreator.cleanLinkToken {
            score += 4
            basis = .userMentionedMetadata
            facts.append("both mention \(sourceCreator)")
        }

        if let sourceYear = source.year?.nilIfBlank,
           let candidateYear = candidate.year?.nilIfBlank,
           sourceYear == candidateYear {
            score += 2
            basis = .userMentionedMetadata
            facts.append("both point to \(sourceYear)")
        }

        if !sharedKeywords.isEmpty {
            score += min(sharedKeywords.count, 4)
            if basis != .userMentionedMetadata && basis != .emotion {
                basis = .memoryTheme
            }
        }

        return (score, basis, localReason(source: source, candidate: candidate, basis: basis, keywordPhrase: keywordPhrase, facts: facts))
    }

    private func localReason(
        source: EchoMemory,
        candidate: EchoMemory,
        basis: EchoMemoryLinkBasis,
        keywordPhrase: String?,
        facts: [String]
    ) -> String {
        let factPhrase = facts.prefix(2).joined(separator: ", and ")

        switch basis {
        case .userMentionedMetadata:
            if let keywordPhrase, !factPhrase.isEmpty {
                return "\(factPhrase.capitalizedFirst); the memories also circle around \(keywordPhrase)."
            }
            if !factPhrase.isEmpty {
                return "\(factPhrase.capitalizedFirst), giving these Echoes a concrete shared reference."
            }
            return "Both Echoes share concrete details provided in the cards."
        case .emotion:
            if let keywordPhrase {
                return "Both carry \(source.emotion.title.lowercased()) through memories of \(keywordPhrase)."
            }
            if !factPhrase.isEmpty {
                return "Both carry \(source.emotion.title.lowercased()), and \(factPhrase)."
            }
            return "Both Echoes carry a similar emotional weight: \(source.emotion.title.lowercased())."
        case .memoryTheme:
            if let keywordPhrase {
                return "The memories return to the same motif: \(keywordPhrase)."
            }
            return "The memories seem to move through a similar personal theme."
        case .modelInference:
            if let keywordPhrase {
                return "Suggested because both Echoes seem to orbit \(keywordPhrase)."
            }
            return "Suggested as a possible thematic connection."
        }
    }

    private func foundationModelLinks(for source: EchoMemory, candidates: [EchoMemory]) async throws -> [EchoMemoryLink] {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw EchoMemoryLinkError.foundationModelUnavailable
        }

        let indexedCandidates = candidates.enumerated().map { index, memory in
            """
            Candidate \(index + 1):
            Title: \(memory.title)
            Creator: \(memory.creator ?? "Not provided")
            Category: \(memory.category.title)
            Emotion: \(memory.emotion.title)
            Year: \(memory.year ?? "Not provided")
            Memory: \(memory.memory)
            Summary: \(memory.echoLine)
            """
        }.joined(separator: "\n\n")

        let session = LanguageModelSession(
            model: model,
            instructions: """
            You suggest connections between saved Echo memory cards.
            Prefer links based on the user's written memories and emotions.
            Do not claim cultural facts unless the fact appears in the provided fields.
            You may use general cultural understanding only for tentative thematic suggestions.
            Keep every reason short and cautious.
            """
        )

        let response = try await session.respond(
            to: """
            Source Echo:
            Title: \(source.title)
            Creator: \(source.creator ?? "Not provided")
            Category: \(source.category.title)
            Emotion: \(source.emotion.title)
            Year: \(source.year ?? "Not provided")
            Memory: \(source.memory)
            Echo line: \(source.echoLine)

            Candidate Echoes:
            \(indexedCandidates)

            Return up to 5 useful connections. Use candidateNumber to identify the candidate.
            Do not include weak or generic links.
            """,
            generating: GeneratedEchoLinks.self
        )

        return response.content.links.compactMap { generated in
            guard candidates.indices.contains(generated.candidateNumber - 1) else { return nil }
            let reason = generated.reason.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !reason.isEmpty else { return nil }

            return EchoMemoryLink(
                target: candidates[generated.candidateNumber - 1],
                basis: generated.basis.linkBasis,
                reason: String(reason.prefix(140)),
                confidence: generated.confidence.linkConfidence,
                score: generated.confidence.linkScore
            )
        }
    }

    private func store(_ links: [EchoMemoryLink], for source: EchoMemory, in modelContext: ModelContext, save: Bool = true) throws {
        guard !links.isEmpty else { return }

        let allStoredLinks = try modelContext.fetch(FetchDescriptor<EchoMemoryStoredLink>())
        let sourceStoredLinks = allStoredLinks.filter { $0.sourceMemoryID == source.id || $0.targetMemoryID == source.id }
        var bestLinksByKey: [String: StoredLinkCandidate] = [:]
        for storedLink in sourceStoredLinks {
            let key = storedLinkKey(sourceID: storedLink.sourceMemoryID, targetID: storedLink.targetMemoryID)
            let candidate = StoredLinkCandidate.stored(storedLink)
            if let existing = bestLinksByKey[key] {
                if candidate.isStronger(than: existing) {
                    bestLinksByKey[key] = candidate
                }
            } else {
                bestLinksByKey[key] = candidate
            }
        }

        for link in links {
            let key = storedLinkKey(sourceID: source.id, targetID: link.target.id)
            let candidate = StoredLinkCandidate.runtime(link)

            if let existing = bestLinksByKey[key] {
                if candidate.isStronger(than: existing) {
                    bestLinksByKey[key] = candidate
                }
            } else {
                bestLinksByKey[key] = candidate
            }
        }

        let selectedKeys = Set(
            bestLinksByKey
                .sorted { first, second in first.value.isStronger(than: second.value) }
                .prefix(Self.maxStoredLinksPerEcho)
                .map(\.key)
        )

        for storedLink in sourceStoredLinks {
            let key = storedLinkKey(sourceID: storedLink.sourceMemoryID, targetID: storedLink.targetMemoryID)
            if !selectedKeys.contains(key) || bestLinksByKey[key]?.runtimeLink != nil {
                modelContext.delete(storedLink)
            }
        }

        var affectedMemoryIDs: Set<UUID> = [source.id]

        for key in selectedKeys {
            guard let link = bestLinksByKey[key]?.runtimeLink else { continue }
            affectedMemoryIDs.insert(link.target.id)
            modelContext.insert(
                EchoMemoryStoredLink(
                    sourceMemoryID: source.id,
                    targetMemoryID: link.target.id,
                    basis: link.basis,
                    reason: link.reason,
                    confidence: link.confidence,
                    score: link.score
                )
            )
        }

        for storedLink in sourceStoredLinks {
            affectedMemoryIDs.insert(storedLink.sourceMemoryID)
            affectedMemoryIDs.insert(storedLink.targetMemoryID)
        }

        try enforceStoredLinkLimit(for: affectedMemoryIDs, in: modelContext)

        if save {
            try modelContext.save()
        }
    }

    private func enforceStoredLinkLimit(for memoryIDs: Set<UUID>, in modelContext: ModelContext) throws {
        let storedLinks = try modelContext.fetch(FetchDescriptor<EchoMemoryStoredLink>())
        var deletedLinkIDs = Set<UUID>()

        for memoryID in memoryIDs {
            let relatedLinks = storedLinks
                .filter { !deletedLinkIDs.contains($0.id) }
                .filter { $0.sourceMemoryID == memoryID || $0.targetMemoryID == memoryID }
                .sorted { first, second in first.isStronger(than: second) }

            guard relatedLinks.count > Self.maxStoredLinksPerEcho else { continue }

            for storedLink in relatedLinks.dropFirst(Self.maxStoredLinksPerEcho) {
                deletedLinkIDs.insert(storedLink.id)
                modelContext.delete(storedLink)
            }
        }
    }

    private func storedLinkKeys(from storedLinks: [EchoMemoryStoredLink]) -> Set<String> {
        Set(storedLinks.map { storedLinkKey(sourceID: $0.sourceMemoryID, targetID: $0.targetMemoryID) })
    }

    private func storedLinkKey(sourceID: UUID, targetID: UUID) -> String {
        [sourceID.uuidString, targetID.uuidString].sorted().joined(separator: "-")
    }

    private func merge(_ modelLinks: [EchoMemoryLink], with heuristicLinks: [EchoMemoryLink]) -> [EchoMemoryLink] {
        var usedIDs = Set<UUID>()
        var merged: [EchoMemoryLink] = []

        for link in modelLinks + heuristicLinks {
            guard !usedIDs.contains(link.target.id) else { continue }
            usedIDs.insert(link.target.id)
            merged.append(link)
        }

        return merged
    }
}

private struct ScoredLink {
    let link: EchoMemoryLink
    let score: Int
}

private enum StoredLinkCandidate {
    case stored(EchoMemoryStoredLink)
    case runtime(EchoMemoryLink)

    var score: Int {
        switch self {
        case .stored(let link): link.score
        case .runtime(let link): link.score
        }
    }

    var createdAt: Date {
        switch self {
        case .stored(let link): link.createdAt
        case .runtime(let link): link.target.createdAt
        }
    }

    var runtimeLink: EchoMemoryLink? {
        switch self {
        case .runtime(let link): link
        case .stored: nil
        }
    }

    func isStronger(than other: StoredLinkCandidate) -> Bool {
        if score == other.score {
            return createdAt > other.createdAt
        }
        return score > other.score
    }
}

private extension EchoMemoryStoredLink {
    func isStronger(than other: EchoMemoryStoredLink) -> Bool {
        if score == other.score {
            return createdAt > other.createdAt
        }
        return score > other.score
    }
}

private enum EchoMemoryLinkError: Error {
    case foundationModelUnavailable
}

@Generable(description: "Suggested links between Echo memory cards")
private struct GeneratedEchoLinks {
    @Guide(description: "Useful links. Omit weak or generic connections.")
    var links: [GeneratedEchoLink]
}

@Generable(description: "One suggested Echo connection")
private struct GeneratedEchoLink {
    @Guide(description: "The 1-based number of the matching candidate Echo")
    var candidateNumber: Int

    @Guide(description: "Why this Echo is connected to the source Echo, under 22 words")
    var reason: String

    @Guide(description: "The safest basis for the connection")
    var basis: GeneratedEchoLinkBasis

    @Guide(description: "Confidence that the connection is supported by provided text")
    var confidence: GeneratedEchoLinkConfidence
}

@Generable(description: "Allowed Echo link bases")
private enum GeneratedEchoLinkBasis {
    case emotion
    case memoryTheme
    case userMentionedMetadata
    case modelInference

    var linkBasis: EchoMemoryLinkBasis {
        switch self {
        case .emotion: .emotion
        case .memoryTheme: .memoryTheme
        case .userMentionedMetadata: .userMentionedMetadata
        case .modelInference: .modelInference
        }
    }
}

@Generable(description: "Allowed Echo link confidence levels")
private enum GeneratedEchoLinkConfidence {
    case high
    case medium
    case low

    var linkConfidence: EchoMemoryLinkConfidence {
        switch self {
        case .high: .high
        case .medium: .medium
        case .low: .low
        }
    }

    var linkScore: Int {
        switch self {
        case .high: 5
        case .medium: 3
        case .low: 1
        }
    }
}

private extension EchoMemory {
    var linkKeywords: Set<String> {
        Set((title + " " + memory + " " + echoLine)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.cleanLinkToken }
            .compactMap { token in
                guard let token, token.count >= 4, !Self.linkStopwords.contains(token) else { return nil }
                return token
            })
    }

    static let linkStopwords: Set<String> = [
        "about", "after", "again", "also", "because", "been", "both", "came", "could", "echo", "even",
        "felt", "first", "from", "have", "inside", "into", "just", "keep", "made", "memory", "more", "over",
        "still", "that", "their", "them", "then", "there", "these", "they", "this", "time", "want",
        "watched", "were", "when", "with", "would", "your"
    ]
}

private extension Set where Element == String {
    var linkPhrase: String? {
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
    var cleanLinkToken: String? {
        let token = folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return token.isEmpty ? nil : token
    }

    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
