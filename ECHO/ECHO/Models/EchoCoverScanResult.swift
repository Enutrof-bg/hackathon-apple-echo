import Foundation

struct EchoCoverScanResult {
    let title: String?
    let creator: String?
    let year: String?
    let category: EchoCategory
    let confidence: EchoCoverScanConfidence
    let visibleText: String
    let source: EchoCoverScanSource

    var draft: EchoMemoryDraft {
        let resolvedTitle = title?.nilIfBlank ?? "Scanned Cover"
        let resolvedCreator = creator?.nilIfBlank
        let resolvedYear = year?.nilIfBlank

        return EchoMemoryDraft(
            title: resolvedTitle,
            creator: resolvedCreator,
            category: category,
            emotion: .curiosity,
            memory: "",
            echoLine: "",
            year: resolvedYear,
            originalTranscript: visibleText.nilIfBlank,
            discoveryStatus: .notDiscovered
        )
    }
}

enum EchoCoverScanConfidence: String, Codable, CaseIterable {
    case high
    case medium
    case low

    var allowsSpecificFacts: Bool {
        self != .low
    }
}

enum EchoCoverScanSource: String, Codable {
    case appleIntelligence
    case visionOCR
    case manualFallback
}
