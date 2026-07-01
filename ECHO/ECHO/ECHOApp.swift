import SwiftData
import SwiftUI

@main
struct ECHOApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [EchoMemory.self, EchoMemoryStoredLink.self])
    }
}
