import Foundation
import FoundationModels

struct AIExtractionService {
    func createDraft(from transcript: String) async -> EchoMemoryDraft {
        let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedTranscript.isEmpty else {
            return fallbackDraft(from: cleanedTranscript)
        }

        do {
            return try await createFoundationModelDraft(from: cleanedTranscript)
        } catch {
            return fallbackDraft(from: cleanedTranscript)
        }
    }

    private func createFoundationModelDraft(from transcript: String) async throws -> EchoMemoryDraft {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw AIExtractionError.foundationModelUnavailable
        }

        let session = LanguageModelSession(
            model: model,
            instructions: """
            You create personal cultural memory cards for Echo.
            Preserve the user's personal memory. Do not invent creator or year if uncertain.
            Choose exactly one allowed category and one allowed emotion. Keep the echo line emotional, concrete, and under 18 words.
            Interface output should be English, but preserve proper nouns exactly when possible.
            """
        )

        let response = try await session.respond(
            to: prompt(for: transcript),
            generating: GeneratedEchoDraft.self
        )

        return response.content.makeDraft(originalTranscript: transcript).sanitized
    }

    private func prompt(for transcript: String) -> String {
        """
        Extract an Echo memory card from this transcript.

        Allowed categories: \(EchoCategory.allCases.map(\.title).joined(separator: ", "))
        Allowed emotions: \(EchoEmotion.allCases.map(\.title).joined(separator: ", "))

        Rules:
        - title: the cultural work, place, object, or moment being remembered.
        - creator: only if clearly known from the transcript or very likely for a famous work.
        - category: one allowed category only.
        - emotion: one dominant allowed emotion only.
        - memory: preserve the personal memory in first person if possible.
        - echoLine: one short poetic line, maximum 18 words.
        - year: only if explicitly mentioned or clearly present.
        - If creator or year is uncertain, return an empty string.

        Transcript:
        \"\"\"
        \(transcript)
        \"\"\"
        """
    }

    private func fallbackDraft(from transcript: String) -> EchoMemoryDraft {
        let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = extractTitle(from: cleanedTranscript)
        let category = detectCategory(in: cleanedTranscript)
        let emotion = detectEmotion(in: cleanedTranscript)
        let memory = cleanedTranscript.isEmpty ? "A memory I want to keep." : cleanedTranscript

        return EchoMemoryDraft(
            title: title,
            category: category,
            emotion: emotion,
            memory: memory,
            echoLine: makeEchoLine(emotion: emotion),
            year: extractYear(from: cleanedTranscript),
            originalTranscript: cleanedTranscript.isEmpty ? nil : cleanedTranscript
        )
    }

    private func extractTitle(from text: String) -> String {
        let patterns = [
            #"remember ([A-Z0-9][A-Za-z0-9 '&:\-]+)"#,
            #"about ([A-Z0-9][A-Za-z0-9 '&:\-]+)"#,
            #"called ([A-Z0-9][A-Za-z0-9 '&:\-]+)"#
        ]

        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let phrase = String(text[match])
                let title = phrase
                    .replacingOccurrences(of: "remember ", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "about ", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "called ", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".,!?"))
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !title.isEmpty {
                    return String(title.prefix(48))
                }
            }
        }

        return "Untitled Echo"
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

    private func makeEchoLine(emotion: EchoEmotion) -> String {
        switch emotion {
        case .nostalgia: "A memory that still knows the way back."
        case .joy: "A bright trace of something that made life lighter."
        case .wonder: "A moment where the world felt larger than before."
        case .melancholy: "A soft ache kept carefully, not forgotten."
        case .calm: "A quiet place inside the noise of time."
        case .shock: "A memory that arrived suddenly and stayed."
        case .love: "A keepsake shaped by closeness."
        case .curiosity: "A spark that kept asking to be followed."
        }
    }
}

@Generable(description: "A structured Echo cultural memory card")
private struct GeneratedEchoDraft {
    @Guide(description: "The cultural work, place, object, or moment name")
    var title: String

    @Guide(description: "Creator name if certain, otherwise empty")
    var creator: String

    @Guide(description: "One of: Film, Book, Music, Painting, Video Game, Performance, Place, Object, Other")
    var category: String

    @Guide(description: "One of: Nostalgia, Joy, Wonder, Melancholy, Calm, Shock, Love, Curiosity")
    var emotion: String

    @Guide(description: "The personal memory, preserving the user's perspective")
    var memory: String

    @Guide(description: "Short poetic line, maximum 18 words")
    var echoLine: String

    @Guide(description: "Year if certain, otherwise empty")
    var year: String

    func makeDraft(originalTranscript: String) -> EchoMemoryDraft {
        EchoMemoryDraft(
            title: title,
            creator: creator.nilIfBlank,
            category: EchoCategory(generatedValue: category),
            emotion: EchoEmotion(generatedValue: emotion),
            memory: memory,
            echoLine: echoLine,
            year: year.nilIfBlank,
            originalTranscript: originalTranscript
        )
    }
}

private enum AIExtractionError: Error {
    case foundationModelUnavailable
}

private extension EchoCategory {
    init(generatedValue: String) {
        let normalizedValue = generatedValue.normalizedGeneratedValue
        self = Self.allCases.first { category in
            category.title.normalizedGeneratedValue == normalizedValue || category.rawValue.normalizedGeneratedValue == normalizedValue
        } ?? .other
    }
}

private extension EchoEmotion {
    init(generatedValue: String) {
        let normalizedValue = generatedValue.normalizedGeneratedValue
        self = Self.allCases.first { emotion in
            emotion.title.normalizedGeneratedValue == normalizedValue || emotion.rawValue.normalizedGeneratedValue == normalizedValue
        } ?? .nostalgia
    }
}

private extension String {
    var normalizedGeneratedValue: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
