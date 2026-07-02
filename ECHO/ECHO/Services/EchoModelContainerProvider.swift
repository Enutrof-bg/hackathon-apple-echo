import Foundation
import SwiftData

enum EchoModelContainerProvider {
    static let shared: ModelContainer = {
        do {
            return try ModelContainer(for: EchoMemory.self, EchoMemoryStoredLink.self)
        } catch {
            assertionFailure("Echo could not create its persistent model container: \(error)")
            return makeInMemoryFallbackContainer()
        }
    }()

    static func makeContext() -> ModelContext {
        ModelContext(shared)
    }

    private static func makeInMemoryFallbackContainer() -> ModelContainer {
        do {
            let schema = Schema([EchoMemory.self, EchoMemoryStoredLink.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Echo could not create any model container: \(error)")
        }
    }
}
