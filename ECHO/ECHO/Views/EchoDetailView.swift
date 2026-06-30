import SwiftData
import SwiftUI

struct EchoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let memory: EchoMemory
    @State private var isEditing = false
    @State private var deleteError: EchoUserFacingError?
    @State private var isShowingUndoBubble = false
    @State private var pendingDismissTask: Task<Void, Never>?

    private let persistenceService = EchoMemoryPersistenceService()

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
                        detailRow("Created", memory.createdAt.formatted(date: .abbreviated, time: .omitted))

                        if let year = memory.year, !year.isEmpty {
                            detailRow("Year", year)
                        }
                    }
                    .padding(16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
            EditEchoView(memory: memory)
        }
        .alert(item: $deleteError) { error in
            Alert(
                title: Text("Echo could not be moved"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onDisappear {
            pendingDismissTask?.cancel()
        }
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

    private func moveMemoryToTrash() {
        do {
            try persistenceService.moveToTrash(memory, in: modelContext)
            isShowingUndoBubble = true
            scheduleDismissAfterUndoWindow()
        } catch {
            deleteError = EchoUserFacingError(message: error.localizedDescription)
        }
    }

    private func restoreFromTrash() {
        pendingDismissTask?.cancel()

        do {
            try persistenceService.restore(memory, in: modelContext)
            isShowingUndoBubble = false
        } catch {
            deleteError = EchoUserFacingError(message: error.localizedDescription)
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
    .modelContainer(for: EchoMemory.self, inMemory: true)
}
