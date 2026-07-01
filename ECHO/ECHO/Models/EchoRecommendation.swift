import Foundation

struct EchoRecommendation: Identifiable {
    let id = UUID()
    let target: EchoMemory
    let reason: String
    let score: Int
    let basis: EchoRecommendationBasis
}

enum EchoRecommendationBasis: String, CaseIterable {
    case emotionalFit
    case sameCategory
    case sharedCreator
    case sharedTheme
    case discoveryQueue

    var title: String {
        switch self {
        case .emotionalFit: "Mood"
        case .sameCategory: "Category"
        case .sharedCreator: "Creator"
        case .sharedTheme: "Theme"
        case .discoveryQueue: "To Discover"
        }
    }

    var symbolName: String {
        switch self {
        case .emotionalFit: "heart.text.square"
        case .sameCategory: "rectangle.stack"
        case .sharedCreator: "person.text.rectangle"
        case .sharedTheme: "sparkles"
        case .discoveryQueue: "clock.badge.checkmark"
        }
    }
}
