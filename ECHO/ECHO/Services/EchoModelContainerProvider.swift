import Foundation
import SwiftData

enum EchoModelContainerProvider {
    static let shared: ModelContainer = {
        do {
            let schema = Schema([EchoMemory.self, EchoMemoryStoredLink.self])
            let configuration = ModelConfiguration(schema: schema, url: storeURL)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Echo could not create its model container: \(error)")
        }
    }()

    static func makeContext() -> ModelContext {
        ModelContext(shared)
    }

    private static var storeURL: URL {
        let fileManager = FileManager.default
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directoryURL = baseURL.appendingPathComponent("Echo", isDirectory: true)

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            assertionFailure("Echo could not create its SwiftData store directory: \(error)")
        }

        return directoryURL.appendingPathComponent("default.store")
    }
}
