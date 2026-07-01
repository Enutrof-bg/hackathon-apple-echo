import AppIntents
import Foundation
import SwiftData

struct CreateEchoIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Echo"
    static var description = IntentDescription("Create an Echo directly from a spoken or typed memory.")
    static var openAppWhenRun = false

    @Parameter(
        title: "Memory",
        description: "The memory, work, or cultural moment to save as an Echo."
    )
    var memory: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let cleanedMemory = memory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedMemory.isEmpty else {
            return .result(dialog: "Tell me the memory you want to save as an Echo.")
        }

        let modelContext = EchoModelContainerProvider.makeContext()
        let activeMemories = try fetchActiveMemories(in: modelContext)
        let extractionResult = await AIExtractionService().createDraftResult(from: cleanedMemory)
        let savedMemory = try EchoMemoryPersistenceService().insert(extractionResult.draft, in: modelContext)
        try? EchoMemoryLinkService().createAndStoreLinks(for: savedMemory, among: activeMemories, in: modelContext)

        return .result(dialog: "Echo created for \(savedMemory.title).")
    }

    @MainActor
    private func fetchActiveMemories(in modelContext: ModelContext) throws -> [EchoMemory] {
        let descriptor = FetchDescriptor<EchoMemory>(
            sortBy: [SortDescriptor(\EchoMemory.createdAt, order: .reverse)]
        )

        return try modelContext.fetch(descriptor).filter { $0.deletedAt == nil }
    }
}
