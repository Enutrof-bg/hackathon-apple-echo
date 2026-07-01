import Foundation

struct EchoDiscoverySuggestion: Identifiable {
    let id = UUID()
    let draft: EchoMemoryDraft
    let reason: String
    let basis: EchoDiscoverySuggestionBasis
}

enum EchoDiscoverySuggestionBasis: String, CaseIterable {
    case hardcodedSeed
    case futureProvider

    var title: String {
        switch self {
        case .hardcodedSeed: "Curated"
        case .futureProvider: "Suggested"
        }
    }

    var symbolName: String {
        switch self {
        case .hardcodedSeed: "sparkles"
        case .futureProvider: "cloud"
        }
    }
}
