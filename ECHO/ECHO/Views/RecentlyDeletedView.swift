import SwiftData
import SwiftUI

struct RecentlyDeletedView: View {
    @Environment(\.modelContext) private var modelContext

    let memories: [EchoMemory]

    @State private var actionError: EchoUserFacingError?

    private let persistenceService = EchoMemoryPersistenceService()

    private var sortedMemories: [EchoMemory] {
        memories.sorted { first, second in
            (first.deletedAt ?? .distantPast) > (second.deletedAt ?? .distantPast)
        }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            if sortedMemories.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedMemories) { memory in
                            deletedMemoryRow(memory)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Recently Deleted")
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $actionError) { error in
            Alert(
                title: Text("Action failed"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "archivebox.circle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Recently Deleted is empty.")
                .font(.headline)

            Text("Deleted echoes stay here for 30 days before permanent deletion.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private func deletedMemoryRow(_ memory: EchoMemory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            EchoCardView(memory: memory)

            if let deletedAt = memory.deletedAt {
                Text("Deleted \(deletedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                Button {
                    restore(memory)
                } label: {
                    archiveActionLabel("Restore", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Restore \(memory.title)")
                .accessibilityHint("Double tap to move this Echo back to your active archive.")

                Rectangle()
                    .fill(EchoStyle.border.opacity(0.42))
                    .frame(width: 1, height: 38)

                Button(role: .destructive) {
                    deletePermanently(memory)
                } label: {
                    archiveActionLabel("Erase", systemImage: "xmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Erase \(memory.title) permanently")
                .accessibilityHint("Double tap to permanently delete this Echo. This cannot be undone.")
            }
            .overlay(
                Rectangle()
                    .stroke(EchoStyle.border.opacity(0.54), lineWidth: 1)
            )
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func archiveActionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.7)
            .foregroundStyle(EchoStyle.ink)
            .frame(maxWidth: .infinity, minHeight: 38)
            .contentShape(Rectangle())
    }

    private func restore(_ memory: EchoMemory) {
        do {
            try persistenceService.restore(memory, in: modelContext)
        } catch {
            actionError = .persistenceFailure(action: "update Recently Deleted")
        }
    }

    private func deletePermanently(_ memory: EchoMemory) {
        do {
            try persistenceService.deletePermanently(memory, in: modelContext)
        } catch {
            actionError = .persistenceFailure(action: "update Recently Deleted")
        }
    }
}

#Preview {
    NavigationStack {
        RecentlyDeletedView(memories: [])
    }
    .modelContainer(for: [EchoMemory.self, EchoMemoryStoredLink.self], inMemory: true)
}
