import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EchoMemory.createdAt, order: .reverse) private var memories: [EchoMemory]

    @State private var isShowingCapture = false
    @State private var searchText = ""
    @State private var navigation = EchoAppNavigation.shared
    @State private var handledCaptureRequestID = EchoAppNavigation.shared.captureRequestID
    @State private var purgeError: EchoUserFacingError?
#if DEBUG
    @State private var isLoadingSampleEchoes = false
    @State private var isRebuildingLinks = false
#endif

    private let persistenceService = EchoMemoryPersistenceService()
    private let searchService = EchoSearchService()
#if DEBUG
    private let placeholderService = EchoPlaceholderService()
    private let linkService = EchoMemoryLinkService()
#endif

    private var activeMemories: [EchoMemory] {
        memories.filter { $0.deletedAt == nil }
    }

    private var deletedMemories: [EchoMemory] {
        memories.filter { $0.deletedAt != nil }
    }

    private var filteredMemories: [EchoMemory] {
        searchService.search(activeMemories, query: searchText)
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        } else if filteredMemories.isEmpty, isSearching {
                            searchEmptyState
                        } else {
                            memoryList
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Echo")
            .searchable(text: $searchText, prompt: "Search by title, mood, status, memory")
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
                CaptureView(existingMemories: activeMemories)
            }
            .task {
                purgeExpiredDeletedMemoriesIfNeeded()
            }
            .onChange(of: navigation.captureRequestID) { _, requestID in
                guard requestID != handledCaptureRequestID else { return }
                handledCaptureRequestID = requestID
                isShowingCapture = true
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

#if DEBUG
            Button {
                insertPlaceholderEchoes()
            } label: {
                Label(
                    isLoadingSampleEchoes ? "Generating Samples..." : "Load Sample Echoes",
                    systemImage: "sparkles"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isLoadingSampleEchoes || isRebuildingLinks)

            Button {
                rebuildEchoLinks()
            } label: {
                Label(
                    isRebuildingLinks ? "Rebuilding Links..." : "Rebuild Echo Links",
                    systemImage: "point.3.connected.trianglepath.dotted"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(activeMemories.count < 2 || isLoadingSampleEchoes || isRebuildingLinks)
#endif
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

    private var searchEmptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No matching echoes.")
                .font(.headline)

            Text("Try a title, creator, emotion, status, or memory detail.")
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
                    EchoDetailView(memory: memory, candidateMemories: activeMemories)
                } label: {
                    EchoCardView(memory: memory)
                }
                .buttonStyle(.plain)
            }
        }
    }

#if DEBUG
    private func insertPlaceholderEchoes() {
        guard !isLoadingSampleEchoes else { return }
        isLoadingSampleEchoes = true

        Task {
            defer { isLoadingSampleEchoes = false }

            do {
                try await placeholderService.insertPlaceholders(in: modelContext, existingMemories: memories)
            } catch {
                purgeError = .persistenceFailure(action: "update the local collection")
            }
        }
    }

    private func rebuildEchoLinks() {
        guard !isRebuildingLinks else { return }
        isRebuildingLinks = true

        Task {
            defer { isRebuildingLinks = false }

            do {
                try linkService.rebuildStoredLinks(for: activeMemories, in: modelContext)
            } catch {
                purgeError = .persistenceFailure(action: "update the local collection")
            }
        }
    }
#endif

    private func purgeExpiredDeletedMemoriesIfNeeded() {
        do {
            try persistenceService.purgeExpiredDeletedMemories(memories, in: modelContext)
        } catch {
            purgeError = .persistenceFailure(action: "update the local collection")
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [EchoMemory.self, EchoMemoryStoredLink.self], inMemory: true)
}
