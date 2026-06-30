import SwiftData
import SwiftUI

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var transcript = ""
    @State private var generatedMemory: EchoMemory?
    @State private var errorMessage: String?

    private let extractionService = AIExtractionService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Button {
                        errorMessage = "Voice capture is not connected yet. Type your memory instead."
                    } label: {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 84))
                            .foregroundStyle(.blue)
                    }
                    .accessibilityLabel("Start Recording")

                    Text("Tap to record")
                        .font(.headline)

                    Text("Type your memory instead.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

                TextEditor(text: $transcript)
                    .frame(minHeight: 180)
                    .padding(10)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("Create Card") {
                    let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanedTranscript.isEmpty else {
                        errorMessage = "Echo could not shape this memory. You can still save it manually."
                        generatedMemory = extractionService.createMemory(from: "")
                        return
                    }

                    generatedMemory = extractionService.createMemory(from: cleanedTranscript)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)

                Spacer()
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $generatedMemory) { memory in
                ReviewCardView(memory: memory) {
                    generatedMemory = nil
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    CaptureView()
        .modelContainer(for: EchoMemory.self, inMemory: true)
}
