import Foundation
import Speech

struct SpeechRecognitionContextProvider {
    static let maximumContextualStringCount = 100

    static var defaultCulturalTerms: [String] {
        [
            "Akira",
            "Austen",
            "Bach",
            "Balzac",
            "Beyonce",
            "Björk",
            "Bowie",
            "Camus",
            "Cézanne",
            "Chagall",
            "Chihiro",
            "Cortázar",
            "Daft Punk",
            "Dali",
            "Dostoevsky",
            "Dune",
            "Evangelion",
            "Flaubert",
            "Frida Kahlo",
            "Ghibli",
            "Godard",
            "Hitchcock",
            "Hokusai",
            "Kafka",
            "Kendrick Lamar",
            "Kurosawa",
            "Matisse",
            "Miyazaki",
            "Monet",
            "Murakami",
            "Nabokov",
            "Nausicaa",
            "Nirvana",
            "Ozu",
            "Picasso",
            "Radiohead",
            "Ravel",
            "Rimbaud",
            "Scorsese",
            "Severance",
            "Sufjan Stevens",
            "Tarkovsky",
            "Tarantino",
            "Totoro",
            "Truffaut",
            "Twin Peaks",
            "Van Gogh",
            "Varda",
            "Verlaine",
            "Zelda"
        ]
    }

    static func makeAnalysisContext(from strings: [String]) -> AnalysisContext {
        let context = AnalysisContext()
        let normalizedStrings = normalizedContextualStrings(from: strings)

        if !normalizedStrings.isEmpty {
            context.contextualStrings[.general] = normalizedStrings
        }

        return context
    }

    static func normalizedContextualStrings(from strings: [String]) -> [String] {
        var seenTerms = Set<String>()
        var normalizedTerms: [String] = []

        for string in strings {
            let term = string.trimmingCharacters(in: .whitespacesAndNewlines)
            let comparisonKey = term.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

            guard !term.isEmpty, !seenTerms.contains(comparisonKey) else {
                continue
            }

            seenTerms.insert(comparisonKey)
            normalizedTerms.append(term)

            if normalizedTerms.count == maximumContextualStringCount {
                break
            }
        }

        return normalizedTerms
    }
}
