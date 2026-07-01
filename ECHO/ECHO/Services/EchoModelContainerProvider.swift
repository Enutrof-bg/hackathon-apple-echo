import Foundation
import SwiftData

enum EchoModelContainerProvider {
    static let shared: ModelContainer = {
        do {
            return try ModelContainer(for: EchoMemory.self, EchoMemoryStoredLink.self)
        } catch {
            fatalError("Echo could not create its model container: \(error)")
        }
    }()

    static func makeContext() -> ModelContext {
        ModelContext(shared)
    }
}
