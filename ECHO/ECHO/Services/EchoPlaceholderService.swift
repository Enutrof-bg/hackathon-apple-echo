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

        let samples: [EchoMemoryDraft] = [
            EchoMemoryDraft(
                title: "Blade Runner 2049",
                creator: "Denis Villeneuve",
                category: .film,
                emotion: .melancholy,
                memory: "I left the cinema with rain, neon, and loneliness still hanging over everything.",
                echoLine: "Blade Runner 2049 stayed with me as a cold, beautiful city of loneliness.",
                year: "2017"
            ),
            EchoMemoryDraft(
                title: "Her",
                creator: "Spike Jonze",
                category: .film,
                emotion: .melancholy,
                memory: "It made technology feel warm and painfully intimate, like a voice filling an empty room.",
                echoLine: "Her turned a digital voice into something tender, lonely, and human.",
                year: "2013"
            ),
            EchoMemoryDraft(
                title: "The Lord of the Rings: The Fellowship of the Ring",
                creator: "Peter Jackson",
                category: .film,
                emotion: .nostalgia,
                memory: "Winter evenings still remind me of blankets, courage, and watching Middle-earth with family.",
                echoLine: "The Fellowship of the Ring became a winter ritual about bravery and belonging.",
                year: "2001"
            ),
            EchoMemoryDraft(
                title: "Spirited Away",
                creator: "Hayao Miyazaki",
                category: .film,
                emotion: .wonder,
                memory: "The bathhouse felt endless, strange, frightening, and full of secret rules.",
                echoLine: "Spirited Away stayed with me as wonder hidden inside fear and ordinary gestures.",
                year: "2001"
            ),
            EchoMemoryDraft(
                title: "Parasite",
                creator: "Bong Joon-ho",
                category: .film,
                emotion: .shock,
                memory: "I remember the mood shifting so sharply that the house suddenly felt like a trap.",
                echoLine: "Parasite turned a clever plan into a brutal picture of class and pressure.",
                year: "2019"
            ),
            EchoMemoryDraft(
                title: "In the Mood for Love",
                creator: "Wong Kar-wai",
                category: .film,
                emotion: .melancholy,
                memory: "The hallways, dresses, and silences made longing feel precise and impossible.",
                echoLine: "In the Mood for Love made restraint feel more intense than confession.",
                year: "2000"
            ),
            EchoMemoryDraft(
                title: "Dune",
                creator: "Denis Villeneuve",
                category: .film,
                emotion: .wonder,
                memory: "The scale of the desert and the sound made the world feel ancient and dangerous.",
                echoLine: "Dune stayed with me for its desert scale, ritual, and heavy sense of destiny.",
                year: "2021"
            ),
            EchoMemoryDraft(
                title: "The Matrix",
                creator: "Lana Wachowski, Lilly Wachowski",
                category: .film,
                emotion: .curiosity,
                memory: "It made reality feel flexible, coded, and suspicious in the best possible way.",
                echoLine: "The Matrix made doubt feel stylish, philosophical, and electrically alive.",
                year: "1999"
            ),
            EchoMemoryDraft(
                title: "The Left Hand of Darkness",
                creator: "Ursula K. Le Guin",
                category: .book,
                emotion: .curiosity,
                memory: "I kept thinking about snow, trust, and how another world can alter obvious truths.",
                echoLine: "The Left Hand of Darkness stayed with me for snow, trust, and changed assumptions.",
                year: "1969"
            ),
            EchoMemoryDraft(
                title: "Invisible Cities",
                creator: "Italo Calvino",
                category: .book,
                emotion: .curiosity,
                memory: "I want to return to its imagined cities as maps of memory, architecture, and desire.",
                echoLine: "Invisible Cities feels like a doorway into memory through imaginary places.",
                year: "1972",
                discoveryStatus: .notDiscovered
            ),
            EchoMemoryDraft(
                title: "Beloved",
                creator: "Toni Morrison",
                category: .book,
                emotion: .melancholy,
                memory: "Its ghosts made history feel intimate, painful, and impossible to shut away.",
                echoLine: "Beloved made memory feel haunted by love, violence, and survival.",
                year: "1987"
            ),
            EchoMemoryDraft(
                title: "Norwegian Wood",
                creator: "Haruki Murakami",
                category: .book,
                emotion: .melancholy,
                memory: "The quiet sadness of youth, music, and absence stayed with me for days.",
                echoLine: "Norwegian Wood held onto youth as something tender, fragile, and already lost.",
                year: "1987"
            ),
            EchoMemoryDraft(
                title: "The Great Gatsby",
                creator: "F. Scott Fitzgerald",
                category: .book,
                emotion: .nostalgia,
                memory: "The green light felt like a perfect image of wanting something already gone.",
                echoLine: "The Great Gatsby made longing look glamorous, hollow, and unreachable.",
                year: "1925"
            ),
            EchoMemoryDraft(
                title: "One Hundred Years of Solitude",
                creator: "Gabriel Garcia Marquez",
                category: .book,
                emotion: .wonder,
                memory: "Macondo felt like a family story, a myth, and a weather system all at once.",
                echoLine: "One Hundred Years of Solitude made family history feel magical and circular.",
                year: "1967"
            ),
            EchoMemoryDraft(
                title: "1984",
                creator: "George Orwell",
                category: .book,
                emotion: .shock,
                memory: "Its language of control made surveillance feel cold, ordinary, and terrifyingly plausible.",
                echoLine: "1984 stayed with me as a warning about language, power, and watched lives.",
                year: "1949"
            ),
            EchoMemoryDraft(
                title: "Kind of Blue",
                creator: "Miles Davis",
                category: .music,
                emotion: .calm,
                memory: "It feels like blue-hour concentration, quiet room light, and space between thoughts.",
                echoLine: "Kind of Blue gives calm a spacious, focused, late-evening shape.",
                year: "1959"
            ),
            EchoMemoryDraft(
                title: "Blue",
                creator: "Joni Mitchell",
                category: .music,
                emotion: .love,
                memory: "The songs feel emotionally bare, like someone letting the room hear everything.",
                echoLine: "Blue stayed with me for its open-hearted honesty and delicate ache.",
                year: "1971"
            ),
            EchoMemoryDraft(
                title: "The Starry Night",
                creator: "Vincent van Gogh",
                category: .painting,
                emotion: .wonder,
                memory: "The sky looks restless and alive, as if the night itself is thinking.",
                echoLine: "The Starry Night makes the sky feel turbulent, intimate, and awake.",
                year: "1889"
            ),
            EchoMemoryDraft(
                title: "Guernica",
                creator: "Pablo Picasso",
                category: .painting,
                emotion: .shock,
                memory: "The fractured bodies and screaming shapes made violence feel impossible to look away from.",
                echoLine: "Guernica turns political horror into a broken, unforgettable visual cry.",
                year: "1937"
            ),
            EchoMemoryDraft(
                title: "The Legend of Zelda: Breath of the Wild",
                creator: "Nintendo",
                category: .videoGame,
                emotion: .joy,
                memory: "Climbing toward a distant ridge made exploration feel quiet, free, and personal.",
                echoLine: "Breath of the Wild made discovery feel like curiosity moving through open air.",
                year: "2017"
            )
        ]

        return samples.enumerated().map { index, draft in
            var draft = draft
            draft.originalTranscript = "Temporary real-work debug sample."
            return draft.makePersistedMemory(createdAt: now.addingTimeInterval(TimeInterval(-(index + 1) * 86_400)))
        }
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
