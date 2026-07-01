import AppIntents
import Foundation
import SwiftData

struct MarkEchoDiscoveredIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Echo as Discovered"
    static var description = IntentDescription("Mark a saved not-discovered Echo as discovered.")
    static var openAppWhenRun = false

    @Parameter(title: "Echo")
    var query: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else {
            return .result(dialog: "Which Echo should I mark as discovered?")
        }

        let modelContext = EchoModelContainerProvider.makeContext()
        let activeMemories = try fetchActiveMemories(in: modelContext)
        let notDiscoveredMemories = activeMemories.filter { $0.discoveryStatus == .notDiscovered }
        let matches = EchoSearchService().search(notDiscoveredMemories, query: cleanedQuery)

        guard let memory = matches.first else {
            return .result(dialog: "I could not find a not-discovered Echo matching \(cleanedQuery).")
        }

        memory.discoveryStatus = .discovered
        try modelContext.save()

        return .result(dialog: "Marked \(memory.title) as discovered.")
    }

    @MainActor
    private func fetchActiveMemories(in modelContext: ModelContext) throws -> [EchoMemory] {
        let descriptor = FetchDescriptor<EchoMemory>(
            sortBy: [SortDescriptor(\EchoMemory.createdAt, order: .reverse)]
        )

        return try modelContext.fetch(descriptor).filter { $0.deletedAt == nil }
    }
}
