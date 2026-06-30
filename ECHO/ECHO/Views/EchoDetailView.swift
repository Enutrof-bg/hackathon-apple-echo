import SwiftData
import SwiftUI

struct EchoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let memory: EchoMemory
    @State private var isEditing = false

    var body: some View {
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
        .background(Color(.systemGroupedBackground))
        .navigationTitle(memory.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    isEditing = true
                }
            }

            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    deleteMemory()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditEchoView(memory: memory)
        }
    }

    private func deleteMemory() {
        modelContext.delete(memory)
        try? modelContext.save()
        dismiss()
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
