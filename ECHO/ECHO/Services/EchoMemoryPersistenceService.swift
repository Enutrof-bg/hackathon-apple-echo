import Foundation
import SwiftData

struct EchoMemoryPersistenceService {
    static let trashRetentionDays = 30

    private let linkService = EchoMemoryLinkService()

    @discardableResult
    func insert(_ draft: EchoMemoryDraft, in modelContext: ModelContext) throws -> EchoMemory {
        let memory = draft.makePersistedMemory()
        modelContext.insert(memory)
        try modelContext.save()
        return memory
    }

    func update(_ memory: EchoMemory, with draft: EchoMemoryDraft, in modelContext: ModelContext) throws {
        let draft = draft.sanitized
        memory.title = draft.title
        memory.creator = draft.creator
        memory.category = draft.category
        memory.emotion = draft.emotion
        memory.memory = draft.memory
        memory.echoLine = draft.echoLine
        memory.year = draft.year
        memory.discoveryStatus = draft.discoveryStatus
        try modelContext.save()
    }

    func moveToTrash(_ memory: EchoMemory, in modelContext: ModelContext, deletedAt: Date = Date()) throws {
        memory.deletedAt = deletedAt
        try modelContext.save()
    }

    func restore(_ memory: EchoMemory, in modelContext: ModelContext) throws {
        memory.deletedAt = nil
        try modelContext.save()
    }

    func deletePermanently(_ memory: EchoMemory, in modelContext: ModelContext) throws {
        try linkService.deleteStoredLinks(relatedTo: memory.id, in: modelContext, save: false)
        modelContext.delete(memory)
        try modelContext.save()
    }

    func purgeExpiredDeletedMemories(_ memories: [EchoMemory], in modelContext: ModelContext, now: Date = Date()) throws {
        guard let expirationDate = Calendar.current.date(
            byAdding: .day,
            value: -Self.trashRetentionDays,
            to: now
        ) else { return }

        let expiredMemories = memories.filter { memory in
            guard let deletedAt = memory.deletedAt else { return false }
            return deletedAt <= expirationDate
        }

        guard !expiredMemories.isEmpty else { return }

        for memory in expiredMemories {
            try linkService.deleteStoredLinks(relatedTo: memory.id, in: modelContext, save: false)
            modelContext.delete(memory)
        }

        try modelContext.save()
    }
}
