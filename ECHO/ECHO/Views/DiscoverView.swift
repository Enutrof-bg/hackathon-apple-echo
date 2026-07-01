import SwiftData
import SwiftUI

struct DiscoverView: View {
    @Query(sort: \EchoMemory.createdAt, order: .reverse) private var memories: [EchoMemory]
    @State private var selectedSuggestion: EchoDiscoverySuggestion?

    private let discoveryService = EchoDiscoveryService()

    private var activeMemories: [EchoMemory] {
        memories.filter { $0.deletedAt == nil }
    }

    private var queueItems: [EchoMemory] {
        discoveryService.queueItems(from: memories)
    }

    private var rediscoverItems: [EchoMemory] {
        discoveryService.rediscoverItems(from: memories)
    }

    private var suggestions: [EchoDiscoverySuggestion] {
        discoveryService.suggestions(existingMemories: activeMemories)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        queueSection
                        suggestionsSection
                        rediscoverSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Discover")
            .sheet(item: $selectedSuggestion) { suggestion in
                ReviewCardView(draft: suggestion.draft, existingMemories: activeMemories)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Explore what could become your next Echo.")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Saved discoveries, older memories, and curated suggestions live here until PCC or another recommendation provider takes over.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var queueSection: some View {
        if !queueItems.isEmpty {
            discoverSection(title: "Your Queue", subtitle: "Echoes you saved but have not discovered yet.") {
                LazyVStack(spacing: 12) {
                    ForEach(queueItems) { memory in
                        NavigationLink {
                            EchoDetailView(memory: memory, candidateMemories: activeMemories)
                        } label: {
                            EchoCardView(memory: memory)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var suggestionsSection: some View {
        discoverSection(title: "New Suggestions", subtitle: "Hardcoded for now; replaceable by PCC later.") {
            if suggestions.isEmpty {
                emptySectionText("All current hardcoded suggestions are already in your archive.")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(suggestions) { suggestion in
                        Button {
                            selectedSuggestion = suggestion
                        } label: {
                            suggestionCard(suggestion)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var rediscoverSection: some View {
        if !rediscoverItems.isEmpty {
            discoverSection(title: "Rediscover", subtitle: "Older saved Echoes worth resurfacing.") {
                LazyVStack(spacing: 12) {
                    ForEach(rediscoverItems) { memory in
                        NavigationLink {
                            EchoDetailView(memory: memory, candidateMemories: activeMemories)
                        } label: {
                            EchoCardView(memory: memory)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func discoverSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content()
        }
    }

    private func suggestionCard(_ suggestion: EchoDiscoverySuggestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            EchoCardView(memory: suggestion.draft)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: suggestion.basis.symbolName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(suggestion.basis.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Text(suggestion.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Spacer(minLength: 8)

                Image(systemName: "plus.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }

    private func emptySectionText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    DiscoverView()
        .modelContainer(for: [EchoMemory.self, EchoMemoryStoredLink.self], inMemory: true)
}
