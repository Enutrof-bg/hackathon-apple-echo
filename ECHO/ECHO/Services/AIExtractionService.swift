import Foundation

struct AIExtractionService {
    func createDraft(from transcript: String) -> EchoMemoryDraft {
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
