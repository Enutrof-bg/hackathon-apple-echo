import Foundation
import FoundationModels

struct AIExtractionService {
    private let titleExtractionService = EchoTitleExtractionService()

    func createDraft(from transcript: String) async -> EchoMemoryDraft {
        await createDraftResult(from: transcript).draft
    }

    func createDraftResult(from transcript: String) async -> AIExtractionResult {
        let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedTranscript.isEmpty else {
            return AIExtractionResult(
                draft: fallbackDraft(from: cleanedTranscript),
                generationSource: .localFallback,
                notice: "Type or speak a memory first. Echo can still help you shape it manually."
            )
        }

        do {
            return AIExtractionResult(
                draft: try await createFoundationModelDraft(from: cleanedTranscript),
                generationSource: .foundationModels,
                notice: nil
            )
        } catch AIExtractionError.foundationModelUnavailable {
            return AIExtractionResult(
                draft: fallbackDraft(from: cleanedTranscript),
                generationSource: .localFallback,
                notice: "Apple Intelligence is not available on this device right now. Echo created a basic card locally that you can edit."
            )
        } catch {
            return AIExtractionResult(
                draft: fallbackDraft(from: cleanedTranscript),
                generationSource: .localFallback,
                notice: "Apple Intelligence could not finish this card. Echo created a basic local version that you can edit."
            )
        }
    }

    private func createFoundationModelDraft(from transcript: String) async throws -> EchoMemoryDraft {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw AIExtractionError.foundationModelUnavailable
        }

        let titleCandidate = titleExtractionService.extractTitleCandidate(from: transcript)
        let session = LanguageModelSession(
            model: model,
            instructions: """
            Create Echo memory cards from user transcripts.
            MUST NOT invent facts. If a title, creator, or year is unclear, leave it nil.
            Prefer an incomplete but honest card over a detailed wrong card.
            Keep the user's personal memory close to the transcript.
            Mark the card as notDiscovered when the user describes wanting, planning, or hoping to read, watch, play, visit, or listen later.
            When a title candidate is provided by deterministic parsing, use it as the title unless the transcript clearly contradicts it.
            """
        )

        let response = try await session.respond(
            to: prompt(for: transcript, titleCandidate: titleCandidate),
            generating: GeneratedEchoDraft.self
        )

        return response.content.makeDraft(originalTranscript: transcript, titleCandidate: titleCandidate).sanitized
    }

    private func prompt(for transcript: String, titleCandidate: EchoTitleExtractionResult?) -> String {
        """
        Extract one Echo memory card.

        Rules:
        - If the transcript does not clearly mention a work, place, object, or moment, set title to nil.
        - Set creator only when directly mentioned or extremely certain.
        - Set year only when an explicit 4-digit year appears.
        - Choose one category and one dominant emotion.
        - Set discoveryStatus to notDiscovered if the user has not experienced it yet and is expressing a wish, plan, recommendation, or intention.
        - Preserve the user's memory; do not add events, people, or details.
        - Set confidence to low for vague, noisy, random, or incomplete input.
        \(titleCandidatePrompt(titleCandidate))

        Transcript:
        \"\"\"
        \(transcript)
        \"\"\"
        """
    }

    private func titleCandidatePrompt(_ titleCandidate: EchoTitleExtractionResult?) -> String {
        guard let titleCandidate else { return "" }

        var lines = [
            "",
            "Deterministic parse hint:",
            "- Possible title: \(titleCandidate.title)",
            "- Evidence: \(titleCandidate.evidence)",
            "- Use this exact title unless the transcript clearly contradicts it."
        ]

        if let creator = titleCandidate.creator {
            lines.append("- Possible creator: \(creator)")
        }

        if let category = titleCandidate.category {
            lines.append("- Likely category: \(category.title)")
        }

        if let discoveryStatus = titleCandidate.discoveryStatus {
            lines.append("- Likely discoveryStatus: \(discoveryStatus.rawValue)")
        }

        return lines.joined(separator: "\n")
    }

    private func fallbackDraft(from transcript: String) -> EchoMemoryDraft {
        let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleCandidate = titleExtractionService.extractTitleCandidate(from: cleanedTranscript)
        let title = titleCandidate?.title ?? "Untitled Echo"
        let creator = titleCandidate?.creator
        let category = titleCandidate?.category ?? detectCategory(in: cleanedTranscript)
        let emotion = detectEmotion(in: cleanedTranscript)
        let discoveryStatus = titleCandidate?.discoveryStatus ?? detectDiscoveryStatus(in: cleanedTranscript)
        let memory = cleanedTranscript.isEmpty ? "A memory I want to keep." : cleanedTranscript

        return EchoMemoryDraft(
            title: title,
            creator: creator,
            category: category,
            emotion: emotion,
            memory: memory,
            year: extractYear(from: cleanedTranscript),
            originalTranscript: cleanedTranscript.isEmpty ? nil : cleanedTranscript,
            discoveryStatus: discoveryStatus
        )
    }

    private func detectCategory(in text: String) -> EchoCategory {
        let lowercased = text.lowercased()
        let matches: [(EchoCategory, [String])] = [
            (.film, ["film", "movie", "cinema", "watched"]),
            (.book, ["book", "novel", "read", "author"]),
            (.music, ["song", "music", "album", "track", "listened"]),
            (.painting, ["painting", "museum", "gallery", "canvas"]),
            (.videoGame, ["game", "played", "console"]),
            (.performance, ["show", "concert", "theater", "stage", "performance"]),
            (.place, ["place", "city", "street", "park", "visited"]),
            (.object, ["object", "toy", "gift", "photo"])
        ]

        return matches.first { _, keywords in
            keywords.contains { lowercased.contains($0) }
        }?.0 ?? .other
    }

    private func detectEmotion(in text: String) -> EchoEmotion {
        let lowercased = text.lowercased()
        let matches: [(EchoEmotion, [String])] = [
            (.nostalgia, ["child", "kid", "winter", "again", "used to", "remember"]),
            (.joy, ["happy", "joy", "laugh", "fun"]),
            (.wonder, ["wonder", "amazed", "magic", "beautiful"]),
            (.melancholy, ["sad", "lost", "miss", "lonely"]),
            (.calm, ["safe", "quiet", "peace", "calm"]),
            (.shock, ["shock", "scared", "intense", "surprised"]),
            (.love, ["love", "family", "sister", "brother", "friend"]),
            (.curiosity, ["curious", "discover", "question", "strange"])
        ]

        return matches.first { _, keywords in
            keywords.contains { lowercased.contains($0) }
        }?.0 ?? .nostalgia
    }

    private func extractYear(from text: String) -> String? {
        guard let range = text.range(of: #"\b(19|20)\d{2}\b"#, options: .regularExpression) else { return nil }
        return String(text[range])
    }

    private func detectDiscoveryStatus(in text: String) -> EchoDiscoveryStatus {
        let lowercased = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()
        let notDiscoveredPatterns = [
            "i want to read", "i want to watch", "i want to listen", "i want to play", "i want to visit",
            "i would like to read", "i would like to watch", "i would like to listen", "i would like to play", "i would like to visit",
            "i plan to read", "i plan to watch", "i plan to listen", "i plan to play", "i plan to visit",
            "i hope to read", "i hope to watch", "i hope to listen", "i hope to play", "i hope to visit",
            "i should read", "i should watch", "i should listen", "i should play", "i should visit",
            "someone recommended", "was recommended", "on my list", "watchlist", "reading list",
            "je veux lire", "je veux regarder", "je veux ecouter", "je veux jouer", "je veux visiter",
            "j'aimerais lire", "j'aimerais regarder", "j'aimerais ecouter", "j'aimerais jouer", "j'aimerais visiter",
            "j'aimerai lire", "j'aimerai regarder", "j'aimerai ecouter", "j'aimerai jouer", "j'aimerai visiter",
            "je voudrais lire", "je voudrais regarder", "je voudrais ecouter", "je voudrais jouer", "je voudrais visiter",
            "je compte lire", "je compte regarder", "je compte ecouter", "je compte jouer", "je compte visiter",
            "on m'a recommande", "on m a recommande", "dans ma liste", "a decouvrir", "pas encore decouvert"
        ]

        return notDiscoveredPatterns.contains { lowercased.contains($0) } ? .notDiscovered : .discovered
    }

}

struct AIExtractionResult {
    let draft: EchoMemoryDraft
    let generationSource: AIExtractionGenerationSource
    let notice: String?
}

enum AIExtractionGenerationSource {
    case foundationModels
    case localFallback
}

@Generable(description: "A structured Echo cultural memory card", representNilExplicitlyInGeneratedContent: true)
private struct GeneratedEchoDraft {
    @Guide(description: "The named work, place, object, or moment. Nil if unclear.")
    var title: String?

    @Guide(description: "Creator name only if certain. Nil if uncertain.")
    var creator: String?

    @Guide(description: "Best category for the memory")
    var category: GeneratedEchoCategory

    @Guide(description: "Dominant emotion in the memory")
    var emotion: GeneratedEchoEmotion

    @Guide(description: "Whether the user already experienced this work/place/object, or only wants to discover it later")
    var discoveryStatus: GeneratedEchoDiscoveryStatus

    @Guide(description: "Ignored by the app. The original transcript is preserved as the memory.")
    var memory: String


    @Guide(description: "Explicit four-digit year only. Nil if absent or uncertain.")
    var year: String?

    @Guide(description: "High only when the extracted card is clearly supported by the transcript")
    var confidence: GeneratedEchoConfidence

    func makeDraft(originalTranscript: String, titleCandidate: EchoTitleExtractionResult?) -> EchoMemoryDraft {
        let originalMemory = originalTranscript.trimmedFallback("A memory I want to keep.")
        let cleanedTitle = title.cleanGeneratedOptionalField
        let cleanedCreator = creator.cleanGeneratedOptionalField
        let cleanedYear = year.validGeneratedYear
        let resolvedTitle = titleCandidate?.title ?? (confidence.allowsSpecificFacts ? cleanedTitle : nil) ?? "Untitled Echo"
        let resolvedCreator = titleCandidate?.creator ?? (confidence.allowsSpecificFacts ? cleanedCreator : nil)
        let resolvedCategory = titleCandidate?.category ?? category.echoCategory
        let resolvedDiscoveryStatus = titleCandidate?.discoveryStatus ?? discoveryStatus.echoDiscoveryStatus

        return EchoMemoryDraft(
            title: resolvedTitle,
            creator: resolvedCreator,
            category: resolvedCategory,
            emotion: emotion.echoEmotion,
            memory: originalMemory,
            year: confidence.allowsSpecificFacts ? cleanedYear : nil,
            originalTranscript: originalTranscript,
            discoveryStatus: resolvedDiscoveryStatus
        )
    }
}

@Generable(description: "Allowed Echo categories")
private enum GeneratedEchoCategory {
    case film
    case book
    case music
    case painting
    case videoGame
    case performance
    case place
    case object
    case other

    var echoCategory: EchoCategory {
        switch self {
        case .film: .film
        case .book: .book
        case .music: .music
        case .painting: .painting
        case .videoGame: .videoGame
        case .performance: .performance
        case .place: .place
        case .object: .object
        case .other: .other
        }
    }
}

@Generable(description: "Allowed Echo emotions")
private enum GeneratedEchoEmotion {
    case nostalgia
    case joy
    case wonder
    case melancholy
    case calm
    case shock
    case love
    case curiosity

    var echoEmotion: EchoEmotion {
        switch self {
        case .nostalgia: .nostalgia
        case .joy: .joy
        case .wonder: .wonder
        case .melancholy: .melancholy
        case .calm: .calm
        case .shock: .shock
        case .love: .love
        case .curiosity: .curiosity
        }
    }
}

@Generable(description: "Allowed discovery states")
private enum GeneratedEchoDiscoveryStatus {
    case discovered
    case notDiscovered

    var echoDiscoveryStatus: EchoDiscoveryStatus {
        switch self {
        case .discovered: .discovered
        case .notDiscovered: .notDiscovered
        }
    }
}

@Generable(description: "Extraction confidence")
private enum GeneratedEchoConfidence {
    case high
    case medium
    case low

    var allowsSpecificFacts: Bool {
        self != .low
    }
}

private enum AIExtractionError: Error {
    case foundationModelUnavailable
}

private extension Optional where Wrapped == String {
    var cleanGeneratedOptionalField: String? {
        switch self {
        case .some(let value):
            return value.cleanGeneratedOptionalField
        case .none:
            return nil
        }
    }

    var validGeneratedYear: String? {
        guard let value = cleanGeneratedOptionalField else { return nil }
        guard value.range(of: #"^(19|20)\d{2}$"#, options: .regularExpression) != nil else { return nil }
        return value
    }
}

private extension String {
    var cleanGeneratedOptionalField: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.normalizedGeneratedValue
        let emptyMarkers = [
            "unknown",
            "uncertain",
            "unspecified",
            "notmentioned",
            "notknown",
            "none",
            "nil",
            "null",
            "n/a",
            "na",
            "-"
        ]

        guard !emptyMarkers.contains(normalized) else { return nil }
        return trimmed
    }


    var normalizedGeneratedValue: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
