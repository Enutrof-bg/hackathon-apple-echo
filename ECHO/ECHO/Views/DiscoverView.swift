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
                EchoStyle.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        queueSection
                        suggestionsSection
                        rediscoverSection
                    }
                    .padding(20)
                }
            }
            .sheet(item: $selectedSuggestion) { suggestion in
                ReviewCardView(draft: suggestion.draft, existingMemories: activeMemories)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Discover")
                    .font(.title2)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(0.4)

                Spacer()

                NavigationLink {
                    DiscoverFilterView()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tune Discover filters")
                .accessibilityHint("Double tap to adjust what appears in the discovery section.")
            }

            Rectangle()
                .fill(EchoStyle.border)
                .frame(height: 1)
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
                        .accessibilityHint("Opens this saved work from your discovery queue.")
                    }
                }
            }
        }
    }

    private var suggestionsSection: some View {
        discoverSection(title: "New Suggestions", subtitle: "Curated cards you can add to your collection.") {
            if suggestions.isEmpty {
                emptySectionText("All current suggestions are already in your archive.")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(suggestions) { suggestion in
                        Button {
                            selectedSuggestion = suggestion
                        } label: {
                            suggestionCard(suggestion)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add suggestion, \(suggestion.draft.title)")
                        .accessibilityValue(suggestion.reason)
                        .accessibilityHint("Double tap to review and save this suggested Echo.")
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
                        .accessibilityHint("Opens this older Echo to revisit the memory.")
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
                    .echoSectionTitle()

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(EchoStyle.mutedInk)
            }

            content()
        }
    }

    private func suggestionCard(_ suggestion: EchoDiscoverySuggestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            EchoCardView(memory: suggestion.draft)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: suggestion.basis.symbolName)
                    .font(.caption)
                    .foregroundStyle(EchoStyle.mutedInk)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Why this card?")
                        .echoSectionTitle()

                    Text(suggestion.reason)
                        .font(.caption)
                        .foregroundStyle(EchoStyle.mutedInk)
                        .lineLimit(3)
                }

                Spacer(minLength: 8)

                Image(systemName: "plus.circle")
                    .font(.subheadline)
                    .foregroundStyle(EchoStyle.mutedInk)
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(EchoStyle.border.opacity(0.32), lineWidth: 1)
        )
    }

    private func emptySectionText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(EchoStyle.mutedInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .echoGlassPanel(tint: EchoStyle.accent.opacity(0.06))
    }
}

#Preview {
    DiscoverView()
        .modelContainer(for: [EchoMemory.self, EchoMemoryStoredLink.self], inMemory: true)
}
