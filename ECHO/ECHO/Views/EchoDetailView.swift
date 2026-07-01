import SwiftData
import SwiftUI

struct EchoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \EchoMemoryStoredLink.createdAt, order: .reverse) private var storedLinks: [EchoMemoryStoredLink]

    let memory: EchoMemory
    let candidateMemories: [EchoMemory]

    @State private var relatedLinks: [EchoMemoryLink] = []
    @State private var isLoadingRelatedLinks = false
    @State private var isEditing = false
    @State private var deleteError: EchoUserFacingError?
    @State private var isShowingUndoBubble = false
    @State private var pendingDismissTask: Task<Void, Never>?

    private let persistenceService = EchoMemoryPersistenceService()
    private let linkService = EchoMemoryLinkService()

    init(memory: EchoMemory, candidateMemories: [EchoMemory] = []) {
        self.memory = memory
        self.candidateMemories = candidateMemories
    }

    private var displayedRelatedLinks: [EchoMemoryLink] {
        linkService.displayedLinks(from: relatedLinks)
    }

    private var relatedLinkRefreshID: String {
        let memoryIDs = candidateMemories.map(\.id.uuidString).joined(separator: ",")
        let linkIDs = storedLinks.map(\.id.uuidString).joined(separator: ",")
        return memory.id.uuidString + "|" + memoryIDs + "|" + linkIDs
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    EchoCardView(memory: memory)

                    detailSection(title: "Memory", text: memory.memory)
                    detailSection(title: "Echo", text: memory.echoLine)

                    VStack(alignment: .leading, spacing: 8) {
                        detailRow("Category", memory.category.title)
                        detailRow("Emotion", memory.emotion.title)
                        detailRow("Status", memory.discoveryStatus.title)
                        detailRow("Created", memory.createdAt.formatted(date: .abbreviated, time: .omitted))

                        if let year = memory.year, !year.isEmpty {
                            detailRow("Year", year)
                        }
                    }
                    .padding(16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    relatedEchoesSection
                }
                .padding(20)
            }

            if isShowingUndoBubble {
                undoBubble
                    .padding(20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isShowingUndoBubble)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(memory.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    isEditing = true
                }
                .disabled(memory.deletedAt != nil)
            }

            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    moveMemoryToTrash()
                } label: {
                    Label("Move to Recently Deleted", systemImage: "trash")
                }
                .disabled(memory.deletedAt != nil)
            }
        }
        .sheet(isPresented: $isEditing) {
            EditEchoView(memory: memory, candidateMemories: candidateMemories)
        }
        .alert(item: $deleteError) { error in
            Alert(
                title: Text("Echo could not be moved"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .task(id: relatedLinkRefreshID) {
            await loadRelatedLinks()
        }
        .onDisappear {
            pendingDismissTask?.cancel()
        }
    }

    @ViewBuilder
    private var relatedEchoesSection: some View {
        if isLoadingRelatedLinks {
            detailSection(title: "Related Echoes", text: "Looking for meaningful connections...")
        } else if !displayedRelatedLinks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Related Echoes")
                        .font(.headline)

#if DEBUG
                    Spacer()

                    Text("\(displayedRelatedLinks.count)/\(relatedLinks.count) shown")
                        .font(.caption)
                        .foregroundStyle(.secondary)
#endif
                }

                ForEach(displayedRelatedLinks) { link in
                    NavigationLink {
                        EchoDetailView(memory: link.target, candidateMemories: candidateMemories)
                    } label: {
                        relatedEchoRow(link)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
#if DEBUG
            detailSection(title: "Related Echoes", text: relatedLinks.isEmpty ? "No links for this Echo yet. Use Rebuild Echo Links after loading samples, or create another related Echo." : "\(relatedLinks.count) stored link(s), but none reach the display score threshold yet.")
#endif
        }
    }

#if DEBUG
    private func debugMetric(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
#endif

    private func relatedEchoRow(_ link: EchoMemoryLink) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: link.basis.symbolName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(link.target.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(link.basis.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

#if DEBUG
                HStack(spacing: 6) {
                    debugMetric("Score \(link.score)")
                    debugMetric(link.confidence.rawValue.capitalized)
                    debugMetric(link.basis.rawValue)
                }
#endif

                Text(link.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var undoBubble: some View {
        HStack(spacing: 12) {
            Text("Moved to Recently Deleted")
                .font(.subheadline)
                .foregroundStyle(.white)

            Spacer()

            Button("Undo") {
                restoreFromTrash()
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func loadRelatedLinks() async {
        guard candidateMemories.contains(where: { $0.id != memory.id && $0.deletedAt == nil }) else {
            relatedLinks = []
            return
        }

        let storedGraphLinks = linkService.storedLinks(
            for: memory,
            among: candidateMemories,
            storedLinks: storedLinks
        )

        if !storedGraphLinks.isEmpty,
           !linkService.displayedLinks(from: storedGraphLinks).isEmpty {
            relatedLinks = storedGraphLinks
            isLoadingRelatedLinks = false
            return
        }

        isLoadingRelatedLinks = true
        let links = await linkService.suggestedLinks(for: memory, among: candidateMemories)
        relatedLinks = linkService.displayedLinks(from: links).isEmpty ? storedGraphLinks : links
        isLoadingRelatedLinks = false
    }

    private func moveMemoryToTrash() {
        do {
            try persistenceService.moveToTrash(memory, in: modelContext)
            isShowingUndoBubble = true
            scheduleDismissAfterUndoWindow()
        } catch {
            deleteError = .persistenceFailure(action: "update Recently Deleted")
        }
    }

    private func restoreFromTrash() {
        pendingDismissTask?.cancel()

        do {
            try persistenceService.restore(memory, in: modelContext)
            isShowingUndoBubble = false
        } catch {
            deleteError = .persistenceFailure(action: "update Recently Deleted")
        }
    }

    private func scheduleDismissAfterUndoWindow() {
        pendingDismissTask?.cancel()
        pendingDismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                dismiss()
            }
        }
    }

    private func detailSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

#Preview {
    NavigationStack {
        EchoDetailView(
            memory: EchoMemory(
                title: "The Lord of the Rings",
                category: .film,
                emotion: .nostalgia,
                memory: "I watched it every winter with my brother.",
                echoLine: "A winter ritual that made courage feel close again."
            )
        )
    }
    .modelContainer(for: [EchoMemory.self, EchoMemoryStoredLink.self], inMemory: true)
}
