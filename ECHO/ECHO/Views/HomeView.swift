import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EchoMemory.createdAt, order: .reverse) private var memories: [EchoMemory]

    @State private var isShowingCapture = false
    @State private var searchText = ""
    @State private var purgeError: EchoUserFacingError?

    private let persistenceService = EchoMemoryPersistenceService()

    private var activeMemories: [EchoMemory] {
        memories.filter { $0.deletedAt == nil }
    }

    private var deletedMemories: [EchoMemory] {
        memories.filter { $0.deletedAt != nil }
    }

    private var filteredMemories: [EchoMemory] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return activeMemories
        }

        return activeMemories.filter { memory in
            memory.title.localizedCaseInsensitiveContains(searchText)
            || memory.echoLine.localizedCaseInsensitiveContains(searchText)
            || memory.memory.localizedCaseInsensitiveContains(searchText)
            || memory.category.title.localizedCaseInsensitiveContains(searchText)
            || memory.emotion.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header

                        if activeMemories.isEmpty {
                            emptyState
                        } else {
                            memoryList
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Echo")
            .searchable(text: $searchText, prompt: "Search echoes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        RecentlyDeletedView(memories: deletedMemories)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Recently Deleted")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingCapture = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Capture an Echo")
                }
            }
            .sheet(isPresented: $isShowingCapture) {
                CaptureView()
            }
            .task {
                purgeExpiredDeletedMemoriesIfNeeded()
            }
            .alert(item: $purgeError) { error in
                Alert(
                    title: Text("Recently Deleted could not be cleaned"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Collect the culture that stayed with you.")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Button {
                isShowingCapture = true
            } label: {
                Label("Capture an Echo", systemImage: "waveform")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("No echoes yet.")
                .font(.headline)

            Text("Speak about a work, a place, or a moment that stayed with you.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
    }

    private var memoryList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredMemories) { memory in
                NavigationLink {
                    EchoDetailView(memory: memory)
                } label: {
                    EchoCardView(memory: memory)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func purgeExpiredDeletedMemoriesIfNeeded() {
        do {
            try persistenceService.purgeExpiredDeletedMemories(memories, in: modelContext)
        } catch {
            purgeError = EchoUserFacingError(message: error.localizedDescription)
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: EchoMemory.self, inMemory: true)
}
