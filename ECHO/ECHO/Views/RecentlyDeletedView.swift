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
            Image(systemName: "trash")
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

            HStack {
                Button("Restore") {
                    restore(memory)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(role: .destructive) {
                    deletePermanently(memory)
                } label: {
                    Text("Delete Permanently")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func restore(_ memory: EchoMemory) {
        do {
            try persistenceService.restore(memory, in: modelContext)
        } catch {
            actionError = EchoUserFacingError(message: error.localizedDescription)
        }
    }

    private func deletePermanently(_ memory: EchoMemory) {
        do {
            try persistenceService.deletePermanently(memory, in: modelContext)
        } catch {
            actionError = EchoUserFacingError(message: error.localizedDescription)
        }
    }
}

#Preview {
    NavigationStack {
        RecentlyDeletedView(memories: [])
    }
    .modelContainer(for: EchoMemory.self, inMemory: true)
}
