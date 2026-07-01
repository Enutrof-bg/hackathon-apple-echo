import Foundation
import SwiftData

@Model
final class EchoMemoryStoredLink {
    var id: UUID
    var sourceMemoryID: UUID
    var targetMemoryID: UUID
    var basis: EchoMemoryLinkBasis
    var reason: String
    var confidence: EchoMemoryLinkConfidence
    var score: Int = 0
    var createdAt: Date

    init(
        id: UUID = UUID(),
        sourceMemoryID: UUID,
        targetMemoryID: UUID,
        basis: EchoMemoryLinkBasis,
        reason: String,
        confidence: EchoMemoryLinkConfidence,
        score: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceMemoryID = sourceMemoryID
        self.targetMemoryID = targetMemoryID
        self.basis = basis
        self.reason = reason
        self.confidence = confidence
        self.score = score
        self.createdAt = createdAt
    }
}
