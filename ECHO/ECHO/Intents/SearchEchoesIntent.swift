import AppIntents
import Foundation

struct SearchEchoesIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Echoes"
    static var description = IntentDescription("Open Echo and search memories by title, emotion, status, creator, or context.")
    static var openAppWhenRun = true

    @Parameter(title: "Search")
    var query: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else {
            return .result(dialog: "What would you like to search for in Echo?")
        }

        EchoAppNavigation.shared.requestSearch(cleanedQuery)
        return .result(dialog: "Searching Echo for \(cleanedQuery).")
    }
}
