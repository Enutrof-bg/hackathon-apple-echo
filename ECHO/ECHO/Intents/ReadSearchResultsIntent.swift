import AppIntents
import Foundation
import SwiftData

struct ReadSearchResultsIntent: AppIntent {
    static var title: LocalizedStringResource = "Read Echo Search Results"
    static var description = IntentDescription("Read the top Echo search results aloud.")
    static var openAppWhenRun = false

    @Parameter(title: "Search")
    var query: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else {
            return .result(dialog: "What would you like me to search for in Echo?")
        }

        let modelContext = EchoModelContainerProvider.makeContext()
        let activeMemories = try fetchActiveMemories(in: modelContext)
        let results = Array(EchoSearchService().search(activeMemories, query: cleanedQuery).prefix(3))

        guard !results.isEmpty else {
            return .result(dialog: "I found no Echoes for \(cleanedQuery).")
        }

        let resultText = results.enumerated().map { index, memory in
            let summary = memory.echoLine.trimmingCharacters(in: .whitespacesAndNewlines)
            let spokenSummary = summary.isEmpty ? memory.memory : summary
            return "\(index + 1). \(memory.title). \(spokenSummary)"
        }.joined(separator: " ")

        return .result(dialog: "Top Echo results for \(cleanedQuery): \(resultText)")
    }

    @MainActor
    private func fetchActiveMemories(in modelContext: ModelContext) throws -> [EchoMemory] {
        let descriptor = FetchDescriptor<EchoMemory>(
            sortBy: [SortDescriptor(\EchoMemory.createdAt, order: .reverse)]
        )

        return try modelContext.fetch(descriptor).filter { $0.deletedAt == nil }
    }
}
