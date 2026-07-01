import Foundation
import FoundationModels
import SwiftData

#if DEBUG
@MainActor
struct EchoPlaceholderService {
    func insertPlaceholders(in modelContext: ModelContext, existingMemories: [EchoMemory]) async throws {
        var memoriesToInsert = Self.fixedPlaceholders

        if let generatedPlaceholders = try? await generatedPlaceholders() {
            memoriesToInsert.append(contentsOf: generatedPlaceholders)
        }

        let existingTitles = Set(existingMemories.map { $0.title.lowercased() })
        let placeholders = memoriesToInsert.filter { !existingTitles.contains($0.title.lowercased()) }

        guard !placeholders.isEmpty else { return }

        for placeholder in placeholders {
            modelContext.insert(placeholder)
        }

        try modelContext.save()
    }

    private func generatedPlaceholders() async throws -> [EchoMemory] {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw EchoPlaceholderError.foundationModelUnavailable
        }

        let session = LanguageModelSession(
            model: model,
            instructions: """
            Generate fictional sample Echo memory cards for development testing.
            The samples must feel like personal cultural memories, not factual metadata records.
            Use plausible but not overly famous works, places, objects, or performances.
            Do not claim real factual details unless they are generic and safe.
            Make the samples emotionally varied and useful for testing related Echo links.
            """
        )

        let response = try await session.respond(
            to: """
            Create exactly 3 sample Echo cards.
            Requirements:
            - One should connect emotionally to melancholy or loneliness.
            - One should connect to wonder or curiosity.
            - One should connect to nostalgia, family, or ritual.
            - Keep memory under 32 words.
            - Keep echoLine as one clear summary sentence under 22 words, grounded in the memory.
            - Use creator and year only if clearly safe; nil is allowed.
            """,
            generating: GeneratedEchoPlaceholders.self
        )

        let now = Date()
        return response.content.samples.enumerated().map { index, sample in
            sample.makeMemory(createdAt: now.addingTimeInterval(TimeInterval(-(index + 6) * 86_400)))
        }
    }

    private static var fixedPlaceholders: [EchoMemory] {
        let now = Date()

        return [
            EchoMemory(
                title: "Blade Runner 2049",
                creator: "Denis Villeneuve",
                category: .film,
                emotion: .melancholy,
                memory: "I remember leaving the cinema with the rain still in my head. The city felt lonely, huge, and strangely beautiful.",
                echoLine: "Blade Runner 2049 stayed with me for its rain, loneliness, and vast city atmosphere.",
                year: "2017",
                originalTranscript: "I remember Blade Runner 2049 after the cinema, the rain, loneliness, and beauty.",
                createdAt: now.addingTimeInterval(-86_400)
            ),
            EchoMemory(
                title: "Her",
                creator: "Spike Jonze",
                category: .film,
                emotion: .melancholy,
                memory: "Her stayed with me because it made technology feel intimate and sad, like a warm voice in an empty apartment.",
                echoLine: "Her stayed with me because it made technology feel intimate, lonely, and emotionally close.",
                year: "2013",
                originalTranscript: "Her made technology feel intimate, sad, and lonely.",
                createdAt: now.addingTimeInterval(-172_800)
            ),
            EchoMemory(
                title: "The Lord of the Rings",
                creator: "Peter Jackson",
                category: .film,
                emotion: .nostalgia,
                memory: "I watched it every winter with my brother. The music still brings back blankets, cold evenings, and feeling brave together.",
                echoLine: "The Lord of the Rings stayed with me as a winter ritual with my brother.",
                year: "2001",
                originalTranscript: "The Lord of the Rings every winter with my brother made me nostalgic.",
                createdAt: now.addingTimeInterval(-259_200)
            ),
            EchoMemory(
                title: "Spirited Away",
                creator: "Hayao Miyazaki",
                category: .film,
                emotion: .wonder,
                memory: "The bathhouse felt endless when I first saw it, full of strange rules, quiet fear, and magic hiding inside ordinary gestures.",
                echoLine: "Spirited Away stayed with me for its bathhouse, strange rules, fear, and wonder.",
                year: "2001",
                originalTranscript: "Spirited Away gave me wonder, fear, and magic in the bathhouse.",
                createdAt: now.addingTimeInterval(-345_600)
            ),
            EchoMemory(
                title: "The Left Hand of Darkness",
                creator: "Ursula K. Le Guin",
                category: .book,
                emotion: .curiosity,
                memory: "I kept thinking about snow, trust, and how a different world can quietly change what feels obvious about people.",
                echoLine: "The Left Hand of Darkness stayed with me for snow, trust, and changed assumptions about people.",
                year: "1969",
                originalTranscript: "The Left Hand of Darkness made me curious about snow, trust, and people.",
                createdAt: now.addingTimeInterval(-432_000)
            ),
            EchoMemory(
                title: "Invisible Cities",
                creator: "Italo Calvino",
                category: .book,
                emotion: .curiosity,
                memory: "I want to read it because imagined cities feel like a doorway into memory, architecture, and strange inner maps.",
                echoLine: "Invisible Cities is in my discovery queue because imagined cities sound beautiful and strange.",
                year: "1972",
                originalTranscript: "I want to read Invisible Cities because imagined cities sound beautiful and strange.",
                discoveryStatus: .notDiscovered,
                createdAt: now.addingTimeInterval(-518_400)
            )
        ]
    }
}

private enum EchoPlaceholderError: Error {
    case foundationModelUnavailable
}

@Generable(description: "Generated sample Echo cards for development testing")
private struct GeneratedEchoPlaceholders {
    @Guide(description: "Exactly 3 sample Echo memory cards", .count(3))
    var samples: [GeneratedEchoPlaceholder]
}

@Generable(description: "One generated sample Echo card")
private struct GeneratedEchoPlaceholder {
    @Guide(description: "A concise title for the remembered work, place, object, or moment")
    var title: String

    @Guide(description: "Creator only if safe and plausible. Nil if uncertain.")
    var creator: String?

    @Guide(description: "Best Echo category")
    var category: GeneratedPlaceholderCategory

    @Guide(description: "Dominant emotion")
    var emotion: GeneratedPlaceholderEmotion

    @Guide(description: "Personal memory under 32 words")
    var memory: String

    @Guide(description: "Short emotional line under 16 words")
    var echoLine: String

    @Guide(description: "Four-digit year only if safe. Nil if uncertain.")
    var year: String?

    func makeMemory(createdAt: Date) -> EchoMemory {
        let draft = EchoMemoryDraft(
            title: title.trimmedFallback("Generated Echo"),
            creator: creator?.nilIfBlank,
            category: category.echoCategory,
            emotion: emotion.echoEmotion,
            memory: memory.trimmedFallback("A generated memory for testing Echo links."),
            echoLine: echoLine.trimmedFallback("This generated sample summarizes a memory for testing."),
            year: year.validPlaceholderYear,
            originalTranscript: "Generated debug sample from Apple Intelligence."
        ).sanitized

        return draft.makePersistedMemory(createdAt: createdAt)
    }
}

@Generable(description: "Allowed placeholder categories")
private enum GeneratedPlaceholderCategory {
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

@Generable(description: "Allowed placeholder emotions")
private enum GeneratedPlaceholderEmotion {
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

private extension Optional where Wrapped == String {
    var validPlaceholderYear: String? {
        guard let value = self?.nilIfBlank else { return nil }
        guard value.range(of: #"^(19|20)\d{2}$"#, options: .regularExpression) != nil else { return nil }
        return value
    }
}
#endif
