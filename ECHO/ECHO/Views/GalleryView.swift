import SwiftData
import SwiftUI

struct GalleryView: View {
    @Query(sort: \EchoMemory.createdAt, order: .reverse) private var memories: [EchoMemory]

    @State private var selectedFilter: GalleryFilter = .all

    private var activeMemories: [EchoMemory] {
        memories.filter { $0.deletedAt == nil }
    }

    private var deletedMemories: [EchoMemory] {
        memories.filter { $0.deletedAt != nil }
    }

    private var filteredMemories: [EchoMemory] {
        switch selectedFilter {
        case .all, .revealed:
            activeMemories
        case .open:
            []
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
                                    NavigationLink {
                                        EchoDetailView(memory: memory)
                                    } label: {
                                        EchoCardView(memory: memory)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityHint("Double tap to open this Echo detail.")
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
                    .accessibilityHint("Double tap to review, restore, or erase deleted Echoes.")
                }
            }
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
                .accessibilityHint("Double tap to filter the gallery.")
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
        .modelContainer(for: EchoMemory.self, inMemory: true)
}
