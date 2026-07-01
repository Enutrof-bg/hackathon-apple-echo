import Foundation

struct EchoTitleExtractionResult: Equatable {
    let title: String
    let creator: String?
    let category: EchoCategory?
    let discoveryStatus: EchoDiscoveryStatus?
    let evidence: String
}

struct EchoTitleExtractionService {
    func extractTitleCandidate(from transcript: String) -> EchoTitleExtractionResult? {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        for pattern in Self.patterns {
            guard let rawTitle = firstCapture(in: text, pattern: pattern.expression) else { continue }
            guard let extractedWork = cleanedWork(from: rawTitle) else { continue }

            return EchoTitleExtractionResult(
                title: extractedWork.title,
                creator: extractedWork.creator,
                category: pattern.category,
                discoveryStatus: pattern.discoveryStatus,
                evidence: pattern.evidence
            )
        }

        return nil
    }

    private func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange), match.numberOfRanges > 1 else {
            return nil
        }

        guard let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    private func cleanedWork(from rawTitle: String) -> ExtractedWork? {
        let boundaryPattern = #"\s+(?:parce que|because|car|quand|when|mais|but|pour|so that|qui|which|apres|after|avant|before)\b.*$"#
        let withoutTrailingClause = rawTitle.replacingOccurrences(
            of: boundaryPattern,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        let trimmed = trimTitlePunctuation(withoutTrailingClause)
        guard !trimmed.isEmpty else { return nil }

        let split = splitCreator(from: trimmed)
        let title = String(split.title.prefix(80))
        guard !title.isEmpty else { return nil }

        return ExtractedWork(
            title: normalizedTitleCasing(title),
            creator: split.creator.map(normalizedNameCasing)
        )
    }

    private func trimTitlePunctuation(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:()[]{}\"“”"))
    }

    private func splitCreator(from text: String) -> (title: String, creator: String?) {
        let patterns = [
            #"^(.+)\s+d[’']\s*([A-Za-zÀ-ÖØ-öø-ÿ][A-Za-zÀ-ÖØ-öø-ÿ’' .-]{2,})$"#,
            #"^(.+)\s+de\s+([A-Za-zÀ-ÖØ-öø-ÿ][A-Za-zÀ-ÖØ-öø-ÿ’' .-]{2,})$"#,
            #"^(.+)\s+par\s+([A-Za-zÀ-ÖØ-öø-ÿ][A-Za-zÀ-ÖØ-öø-ÿ’' .-]{2,})$"#,
            #"^(.+)\s+by\s+([A-Za-z][A-Za-z’' .-]{2,})$"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: nsRange), match.numberOfRanges == 3 else { continue }
            guard let titleRange = Range(match.range(at: 1), in: text),
                  let creatorRange = Range(match.range(at: 2), in: text) else { continue }

            let title = trimTitlePunctuation(String(text[titleRange]))
            let creator = trimTitlePunctuation(String(text[creatorRange]))

            guard isPlausibleCreator(creator), !title.isEmpty else { continue }
            return (title, creator)
        }

        return (text, nil)
    }

    private func isPlausibleCreator(_ creator: String) -> Bool {
        let words = creator
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        guard words.count >= 2 else { return false }
        guard words.allSatisfy({ word in word.contains { $0.isLetter } }) else { return false }

        let firstWord = words[0].folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()
        let articleStarts: Set<String> = ["a", "an", "the", "le", "la", "les", "un", "une", "des"]
        guard !articleStarts.contains(firstWord) else { return false }

        return true
    }

    private func normalizedTitleCasing(_ title: String) -> String {
        guard title == title.lowercased() else { return title }

        var result = ""
        var shouldCapitalizeNextLetter = true

        for character in title {
            if shouldCapitalizeNextLetter, character.isLetter {
                result.append(contentsOf: character.uppercased())
                shouldCapitalizeNextLetter = false
            } else {
                result.append(character)
            }

            if character == "'" || character == "’" {
                shouldCapitalizeNextLetter = true
            }
        }

        return result
    }

    private func normalizedNameCasing(_ name: String) -> String {
        guard name == name.lowercased() else { return name }

        return name
            .split(separator: " ")
            .map { part in
                guard let first = part.first else { return "" }
                return first.uppercased() + part.dropFirst()
            }
            .joined(separator: " ")
    }

    fileprivate static let titleBoundary = #"\s+(.+?)(?=\s+(?:parce que|because|car|quand|when|mais|but|pour|so that|qui|which|apres|after|avant|before|et\s+j[’']?|et\s+je|and\s+i)\b|[.!?,;:]|$)"#

    private static let patterns: [TitlePattern] = [
        TitlePattern(prefix: #"\bj[’']?aimerais\s+lire"#, category: .book, discoveryStatus: .notDiscovered, evidence: "future reading intent"),
        TitlePattern(prefix: #"\bj[’']?aimerai\s+lire"#, category: .book, discoveryStatus: .notDiscovered, evidence: "future reading intent"),
        TitlePattern(prefix: #"\bje\s+(?:veux|voudrais|compte|devrais)\s+lire"#, category: .book, discoveryStatus: .notDiscovered, evidence: "future reading intent"),
        TitlePattern(prefix: #"\bj[’']?ai\s+envie\s+de\s+lire"#, category: .book, discoveryStatus: .notDiscovered, evidence: "future reading intent"),
        TitlePattern(prefix: #"\bi\s+(?:want|would\s+like|plan|hope|should)\s+to\s+read"#, category: .book, discoveryStatus: .notDiscovered, evidence: "future reading intent"),
        TitlePattern(prefix: #"\bi[’']?d\s+like\s+to\s+read"#, category: .book, discoveryStatus: .notDiscovered, evidence: "future reading intent"),

        TitlePattern(prefix: #"\bj[’']?aimerais\s+(?:voir|regarder)"#, category: .film, discoveryStatus: .notDiscovered, evidence: "future watching intent"),
        TitlePattern(prefix: #"\bj[’']?aimerai\s+(?:voir|regarder)"#, category: .film, discoveryStatus: .notDiscovered, evidence: "future watching intent"),
        TitlePattern(prefix: #"\bje\s+(?:veux|voudrais|compte|devrais)\s+(?:voir|regarder)"#, category: .film, discoveryStatus: .notDiscovered, evidence: "future watching intent"),
        TitlePattern(prefix: #"\bi\s+(?:want|would\s+like|plan|hope|should)\s+to\s+(?:watch|see)"#, category: .film, discoveryStatus: .notDiscovered, evidence: "future watching intent"),
        TitlePattern(prefix: #"\bi[’']?d\s+like\s+to\s+(?:watch|see)"#, category: .film, discoveryStatus: .notDiscovered, evidence: "future watching intent"),

        TitlePattern(prefix: #"\bj[’']?aimerais\s+ecouter"#, category: .music, discoveryStatus: .notDiscovered, evidence: "future listening intent"),
        TitlePattern(prefix: #"\bj[’']?aimerais\s+écouter"#, category: .music, discoveryStatus: .notDiscovered, evidence: "future listening intent"),
        TitlePattern(prefix: #"\bje\s+(?:veux|voudrais|compte|devrais)\s+(?:ecouter|écouter)"#, category: .music, discoveryStatus: .notDiscovered, evidence: "future listening intent"),
        TitlePattern(prefix: #"\bi\s+(?:want|would\s+like|plan|hope|should)\s+to\s+listen\s+to"#, category: .music, discoveryStatus: .notDiscovered, evidence: "future listening intent"),

        TitlePattern(prefix: #"\bj[’']?aimerais\s+jouer\s+a"#, category: .videoGame, discoveryStatus: .notDiscovered, evidence: "future playing intent"),
        TitlePattern(prefix: #"\bj[’']?aimerais\s+jouer\s+à"#, category: .videoGame, discoveryStatus: .notDiscovered, evidence: "future playing intent"),
        TitlePattern(prefix: #"\bje\s+(?:veux|voudrais|compte|devrais)\s+jouer\s+(?:a|à)"#, category: .videoGame, discoveryStatus: .notDiscovered, evidence: "future playing intent"),
        TitlePattern(prefix: #"\bi\s+(?:want|would\s+like|plan|hope|should)\s+to\s+play"#, category: .videoGame, discoveryStatus: .notDiscovered, evidence: "future playing intent"),

        TitlePattern(prefix: #"\bon\s+m[’']?a\s+recommande"#, category: nil, discoveryStatus: .notDiscovered, evidence: "recommendation intent"),
        TitlePattern(prefix: #"\bon\s+m[’']?a\s+recommandé"#, category: nil, discoveryStatus: .notDiscovered, evidence: "recommendation intent"),
        TitlePattern(prefix: #"\bsomeone\s+recommended"#, category: nil, discoveryStatus: .notDiscovered, evidence: "recommendation intent"),

        TitlePattern(prefix: #"\bje\s+lis"#, category: .book, discoveryStatus: .discovered, evidence: "current reading mention"),
        TitlePattern(prefix: #"\bje\s+suis\s+en\s+train\s+de\s+lire"#, category: .book, discoveryStatus: .discovered, evidence: "current reading mention"),
        TitlePattern(prefix: #"\bj[’']?ai\s+lu"#, category: .book, discoveryStatus: .discovered, evidence: "past reading mention"),
        TitlePattern(prefix: #"\bi\s+(?:read|am\s+reading)"#, category: .book, discoveryStatus: .discovered, evidence: "reading mention"),
        TitlePattern(prefix: #"\bj[’']?ai\s+(?:vu|regarde|regardé)"#, category: .film, discoveryStatus: .discovered, evidence: "watching mention"),
        TitlePattern(prefix: #"\bi\s+(?:watched|saw)"#, category: .film, discoveryStatus: .discovered, evidence: "watching mention"),
        TitlePattern(prefix: #"\bj[’']?ai\s+(?:ecoute|écouté|ecouté)"#, category: .music, discoveryStatus: .discovered, evidence: "listening mention"),
        TitlePattern(prefix: #"\bi\s+listened\s+to"#, category: .music, discoveryStatus: .discovered, evidence: "listening mention"),
        TitlePattern(prefix: #"\bremember"#, category: nil, discoveryStatus: .discovered, evidence: "memory mention"),
        TitlePattern(prefix: #"\babout"#, category: nil, discoveryStatus: nil, evidence: "about mention"),
        TitlePattern(prefix: #"\bcalled"#, category: nil, discoveryStatus: nil, evidence: "called mention")
    ]
}

private struct ExtractedWork {
    let title: String
    let creator: String?
}

private struct TitlePattern {
    let expression: String
    let category: EchoCategory?
    let discoveryStatus: EchoDiscoveryStatus?
    let evidence: String

    init(prefix: String, category: EchoCategory?, discoveryStatus: EchoDiscoveryStatus?, evidence: String) {
        self.expression = prefix + EchoTitleExtractionService.titleBoundary
        self.category = category
        self.discoveryStatus = discoveryStatus
        self.evidence = evidence
    }
}
