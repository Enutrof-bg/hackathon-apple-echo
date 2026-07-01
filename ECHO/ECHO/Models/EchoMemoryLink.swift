import Foundation

struct EchoMemoryLink: Identifiable {
    let id = UUID()
    let target: EchoMemory
    let basis: EchoMemoryLinkBasis
    let reason: String
    let confidence: EchoMemoryLinkConfidence
    let score: Int
}

enum EchoMemoryLinkBasis: String, Codable, CaseIterable {
    case emotion
    case memoryTheme
    case userMentionedMetadata
    case modelInference

    var title: String {
        switch self {
        case .emotion: "Emotion"
        case .memoryTheme: "Memory"
        case .userMentionedMetadata: "Details"
        case .modelInference: "Suggested"
        }
    }

    var symbolName: String {
        switch self {
        case .emotion: "heart"
        case .memoryTheme: "text.bubble"
        case .userMentionedMetadata: "tag"
        case .modelInference: "sparkles"
        }
    }
}

enum EchoMemoryLinkConfidence: String, Codable {
    case high
    case medium
    case low
}
