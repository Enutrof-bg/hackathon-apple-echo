import SwiftData
import SwiftUI

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss

    var existingMemories: [EchoMemory] = []

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
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 180)
                    .padding(10)
                    .echoGlassPanel(tint: EchoStyle.accent.opacity(0.06))

                if let message = activeMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task {
                        await createCard()
                    }
                } label: {
                    Label(isCreatingCard ? "Creating Card..." : "Create Card", systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .echoGlassButtonStyle(prominent: true)
                .controlSize(.large)
                .disabled(isCreatingCard)

                Spacer()
            }
            .padding(20)
            .background(EchoStyle.background)
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
                ReviewCardView(draft: draft, existingMemories: existingMemories) {
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
                    .font(.system(size: 72))
                    .foregroundStyle(transcriptionService.state.isListening ? .red : EchoStyle.accent)
                    .frame(width: 104, height: 104)
                    .echoGlassPanel(tint: transcriptionService.state.isListening ? .red.opacity(0.14) : EchoStyle.accent.opacity(0.16))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(transcriptionService.state.isListening ? "Stop Recording" : "Start Recording")
            .disabled(transcriptionService.state.isStopping)

            Text(transcriptionService.state.statusText)
                .font(.headline)
                .foregroundStyle(EchoStyle.graphite)
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
                .echoGlassButtonStyle()

                if transcriptionService.state.isListening {
                    Button("Stop") {
                        transcriptionService.stopTranscribing()
                    }
                    .echoGlassButtonStyle(prominent: true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .echoGlassPanel(tint: EchoStyle.accent.opacity(0.10))
    }

    private var textModeHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "keyboard")
                .font(.system(size: 44))
                .foregroundStyle(EchoStyle.accent)

            Text("Type your memory")
                .font(.headline)
                .foregroundStyle(EchoStyle.graphite)

            Text("You can write directly instead of recording voice.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .echoGlassPanel(tint: EchoStyle.accent.opacity(0.10))
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
            transcriptionService.updateContextualStrings(
                SpeechRecognitionContextProvider.contextualStrings(from: existingMemories)
            )
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
        let result = await extractionService.createDraftResult(from: cleanedTranscript)
        generatedDraft = result.draft
        errorMessage = result.notice
        isCreatingCard = false
    }
}

#Preview {
    CaptureView()
        .modelContainer(for: [EchoMemory.self, EchoMemoryStoredLink.self], inMemory: true)
}
