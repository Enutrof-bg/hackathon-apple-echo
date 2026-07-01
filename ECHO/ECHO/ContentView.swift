import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Echo", systemImage: "rectangle.stack")
                }

            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "safari")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [EchoMemory.self, EchoMemoryStoredLink.self], inMemory: true)
}
