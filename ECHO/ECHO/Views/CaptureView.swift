import SwiftData
import SwiftUI

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var inputMode: CaptureInputMode = .speech
    @State private var transcript = ""
    @State private var generatedDraft: EchoMemoryDraft?
    @State private var errorMessage: String?
    @State private var isCreatingCard = false
    @State private var transcriptionService = SpeechTranscriptionService()

    private let extractionService = AIExtractionService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("Input Mode", selection: $inputMode) {
                    ForEach(CaptureInputMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch inputMode {
                case .speech:
                    speechControls
                case .text:
                    textModeHeader
                }

                TextEditor(text: $transcript)
                    .frame(minHeight: 180)
                    .padding(10)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                if let message = activeMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(isCreatingCard ? "Creating Card..." : "Create Card") {
                    Task {
                        await createCard()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(isCreatingCard)

                Spacer()
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        transcriptionService.stopTranscribing()
                        dismiss()
                    }
                }
            }
            .sheet(item: $generatedDraft) { draft in
                ReviewCardView(draft: draft) {
                    generatedDraft = nil
                    dismiss()
                }
            }
            .onChange(of: transcriptionService.transcript) { _, newTranscript in
                guard inputMode == .speech else { return }
                transcript = newTranscript
            }
            .onChange(of: inputMode) { _, newMode in
                if newMode == .text {
                    transcriptionService.stopTranscribing()
                }
            }
            .onDisappear {
                transcriptionService.stopTranscribing()
            }
        }
    }

    private var speechControls: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await toggleSpeechCapture()
                }
            } label: {
                Image(systemName: transcriptionService.state.isListening ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 84))
                    .foregroundStyle(transcriptionService.state.isListening ? .red : .blue)
            }
            .accessibilityLabel(transcriptionService.state.isListening ? "Stop Recording" : "Start Recording")

            Text(transcriptionService.state.statusText)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Recognition language: \(transcriptionService.recognitionLanguageName)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Clear") {
                    transcript = ""
                    transcriptionService.resetTranscript()
                    errorMessage = nil
                }
                .buttonStyle(.bordered)

                if transcriptionService.state.isListening {
                    Button("Stop") {
                        transcriptionService.stopTranscribing()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private var textModeHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "keyboard")
                .font(.system(size: 44))
                .foregroundStyle(.blue)

            Text("Type your memory")
                .font(.headline)

            Text("You can write directly instead of recording voice.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private var activeMessage: String? {
        if let errorMessage {
            return errorMessage
        }

        if case .failed(let message) = transcriptionService.state {
            return message
        }

        if isCreatingCard {
            return "Shaping this memory into an Echo..."
        }

        if inputMode == .speech {
            return "You can edit the transcript before creating a card."
        }

        return nil
    }

    private func toggleSpeechCapture() async {
        errorMessage = nil

        if transcriptionService.state.isListening {
            transcriptionService.stopTranscribing()
        } else {
            await transcriptionService.startTranscribing()
        }
    }

    private func createCard() async {
        let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTranscript.isEmpty else {
            errorMessage = "Echo could not shape this memory. Speak or type a memory first."
            return
        }

        errorMessage = nil
        isCreatingCard = true
        transcriptionService.stopTranscribing()
        generatedDraft = await extractionService.createDraft(from: cleanedTranscript)
        isCreatingCard = false
    }
}

#Preview {
    CaptureView()
        .modelContainer(for: EchoMemory.self, inMemory: true)
}
