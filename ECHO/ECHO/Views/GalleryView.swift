import SwiftData
import SwiftUI

struct GalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EchoMemory.createdAt, order: .reverse) private var memories: [EchoMemory]

    @State private var selectedFilter: GalleryFilter = .all
    @State private var statusUpdateError: EchoUserFacingError?

    private let persistenceService = EchoMemoryPersistenceService()

    private var activeMemories: [EchoMemory] {
        memories.filter { $0.deletedAt == nil }
    }

    private var deletedMemories: [EchoMemory] {
        memories.filter { $0.deletedAt != nil }
    }

    private var filteredMemories: [EchoMemory] {
        switch selectedFilter {
        case .all:
            activeMemories
        case .open:
            activeMemories.filter { $0.discoveryStatus == .notDiscovered }
        case .revealed:
            activeMemories.filter { $0.discoveryStatus == .discovered }
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                EchoStyle.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        filterRow

                        if filteredMemories.isEmpty {
                            emptyState
                        } else {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(filteredMemories) { memory in
                                    GalleryEchoCard(
                                        memory: memory,
                                        candidateMemories: activeMemories
                                    ) {
                                        toggleDiscoveryStatus(for: memory)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        RecentlyDeletedView(memories: deletedMemories)
                    } label: {
                        Image(systemName: "archivebox")
                    }
                    .accessibilityLabel("Recently Deleted")
                }
            }
            .alert(item: $statusUpdateError) { error in
                Alert(
                    title: Text("Echo status could not be updated"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func toggleDiscoveryStatus(for memory: EchoMemory) {
        do {
            try persistenceService.toggleDiscoveryStatus(for: memory, in: modelContext)
        } catch {
            statusUpdateError = .persistenceFailure(action: "update this Echo status")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Gallery")
                    .font(.title2)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(0.4)

                Spacer()

                Text("\(activeMemories.count) Cards")
                    .font(.caption)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .foregroundStyle(EchoStyle.mutedInk)
            }

            Rectangle()
                .fill(EchoStyle.border)
                .frame(height: 1)
        }
    }

    private var filterRow: some View {
        HStack(spacing: 8) {
            ForEach(GalleryFilter.allCases) { filter in
                Button(filter.title) {
                    selectedFilter = filter
                }
                .font(.caption)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .foregroundStyle(selectedFilter == filter ? EchoStyle.surface : EchoStyle.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selectedFilter == filter ? EchoStyle.ink : .clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(EchoStyle.border.opacity(0.42), lineWidth: 1)
                )
                .accessibilityLabel("Show \(filter.title.lowercased()) cards")
                .accessibilityValue(selectedFilter == filter ? "Selected" : "Not selected")
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(selectedFilter == .open ? "No open cards yet." : "No cards yet.")
                .font(.headline)
                .foregroundStyle(EchoStyle.ink)

            Text("Collect a work you lived or one you want to discover.")
                .font(.subheadline)
                .foregroundStyle(EchoStyle.mutedInk)

            Rectangle()
                .stroke(EchoStyle.border.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .aspectRatio(1, contentMode: .fit)
        }
        .padding(.top, 24)
    }
}

private struct GalleryEchoCard: View {
    let memory: EchoMemory
    let candidateMemories: [EchoMemory]
    let onToggleDiscoveryStatus: () -> Void

    private var stampButtonTitle: String {
        memory.discoveryStatus == .discovered ? "Mark as not discovered" : "Mark as discovered"
    }

    private var stampButtonImageName: String {
        memory.discoveryStatus == .discovered ? "seal.fill" : "seal"
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink {
                EchoDetailView(memory: memory, candidateMemories: candidateMemories)
            } label: {
                EchoCardView(memory: memory)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45)
                    .onEnded { _ in
                        onToggleDiscoveryStatus()
                    }
            )
            .accessibilityHint("Long press to stamp and change discovery status.")

            Button {
                onToggleDiscoveryStatus()
            } label: {
                ZStack {
                    Circle()
                        .fill(EchoStyle.surface)

                    Image(systemName: stampButtonImageName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(EchoStyle.ink)

                    if memory.discoveryStatus == .discovered {
                        Image(systemName: "star.fill")
                            .font(.system(size: 5, weight: .bold))
                            .foregroundStyle(EchoStyle.ink)
                    }
                }
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(memory.discoveryStatus == .discovered ? EchoStyle.surface : EchoStyle.border.opacity(0.34), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(8)
            .accessibilityLabel(stampButtonTitle)
            .accessibilityHint("Double tap to toggle this Echo between discovered and not discovered.")
        }
    }
}

private enum GalleryFilter: String, CaseIterable, Identifiable {
    case all
    case open
    case revealed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .open: "Open"
        case .revealed: "Revealed"
        }
    }
}

#Preview {
    GalleryView()
        .modelContainer(for: [EchoMemory.self, EchoMemoryStoredLink.self], inMemory: true)
}
