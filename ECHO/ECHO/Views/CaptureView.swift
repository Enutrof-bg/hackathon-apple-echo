import SwiftData
import SwiftUI
import UIKit

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss

    var existingMemories: [EchoMemory] = []
    private let autoStartSpeech: Bool

    @State private var inputMode: CaptureInputMode
    @State private var transcript = ""
    @State private var generatedDraft: EchoMemoryDraft?
    @State private var errorMessage: String?
    @State private var isCreatingCard = false
    @State private var isShowingCamera = false
    @State private var isScanningCover = false
    @State private var pendingCoverDraft: EchoMemoryDraft?
    @State private var transcriptionService = SpeechTranscriptionService()
    @State private var didAutoStartSpeech = false

    private let extractionService = AIExtractionService()
    private let coverScanService = EchoCoverScanService()

    init(
        existingMemories: [EchoMemory] = [],
        initialInputMode: CaptureInputMode = .speech,
        autoStartSpeech: Bool = false
    ) {
        self.existingMemories = existingMemories
        self.autoStartSpeech = autoStartSpeech
        _inputMode = State(initialValue: initialInputMode)
    }

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
                case .camera:
                    cameraControls
                }

                if inputMode != .camera {
                    if let pendingCoverDraft {
                        pendingCoverMetadataView(pendingCoverDraft)
                    }

                    TextEditor(text: $transcript)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 180)
                        .padding(10)
                        .echoGlassPanel(tint: EchoStyle.accent.opacity(0.06))
                }

                if let message = activeMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if inputMode != .camera {
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
                }

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
                ReviewCardView(
                    draft: draft,
                    existingMemories: existingMemories,
                    startsEditing: false
                ) {
                    generatedDraft = nil
                    pendingCoverDraft = nil
                    dismiss()
                }
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraImagePicker(sourceType: .camera) { image in
                    isShowingCamera = false
                    Task {
                        await scanCover(image)
                    }
                } onCancel: {
                    isShowingCamera = false
                }
            }
            .onChange(of: transcriptionService.transcript) { _, newTranscript in
                guard inputMode == .speech else { return }
                transcript = newTranscript
            }
            .onChange(of: inputMode) { _, newMode in
                if newMode != .speech {
                    transcriptionService.stopTranscribing()
                }
            }
            .task {
                await autoStartSpeechIfNeeded()
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

    private var cameraControls: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Scan a cover")
                .font(.headline)

            Button(isScanningCover ? "Scanning Cover..." : "Take Cover Photo") {
                errorMessage = nil
                isShowingCamera = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isScanningCover)

            if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                Text("Camera is unavailable here, so Echo will open the photo library.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private func pendingCoverMetadataView(_ draft: EchoMemoryDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Cover metadata", systemImage: "camera.viewfinder")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Button("Clear") {
                    pendingCoverDraft = nil
                }
                .font(.caption)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(draft.title)
                    .font(.headline)

                if let creator = draft.creator, !creator.isEmpty {
                    Text(creator)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Label(draft.category.title, systemImage: draft.category.symbolName)

                    if let year = draft.year, !year.isEmpty {
                        Text(year)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
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

        if isScanningCover {
            return "Reading the cover with Apple Intelligence, then local OCR if needed..."
        }

        if pendingCoverDraft != nil, inputMode != .camera {
            return "Cover metadata is ready. Speak or type the memory so Echo can generate the summary intelligently."
        }

        if inputMode == .speech {
            return "You can edit the transcript before creating a card."
        }

        if inputMode == .camera {
            return "Scan the cover first, then add the memory with speech or text."
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

    private func autoStartSpeechIfNeeded() async {
        guard autoStartSpeech, inputMode == .speech, !didAutoStartSpeech else { return }
        didAutoStartSpeech = true
        await toggleSpeechCapture()
    }

    private func scanCover(_ image: UIImage) async {
        errorMessage = nil
        isScanningCover = true
        let result = await coverScanService.scanCover(from: image)
        pendingCoverDraft = result.draft
        transcript = ""
        transcriptionService.resetTranscript()
        inputMode = .speech
        errorMessage = notice(for: result.source) ?? "Cover metadata captured. Now speak or type the memory."
        isScanningCover = false
    }

    private func notice(for source: EchoCoverScanSource) -> String? {
        switch source {
        case .appleIntelligence:
            return nil
        case .visionOCR:
            return "Apple Intelligence image scan was unavailable. Echo used local OCR instead."
        case .manualFallback:
            return "Echo could not read this cover automatically. You can still fill the card manually."
        }
    }

    private func createCard() async {
        errorMessage = nil
        isCreatingCard = true
        defer { isCreatingCard = false }

        let finalTranscript: String
        if inputMode == .speech {
            finalTranscript = await transcriptionService.finishTranscribingAndReturnTranscript()
            transcript = finalTranscript
        } else {
            finalTranscript = transcript
        }

        let cleanedTranscript = finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTranscript.isEmpty else {
            errorMessage = "Echo could not shape this memory. Speak or type a memory first."
            return
        }

        let result = await extractionService.createDraftResult(from: cleanedTranscript)
        generatedDraft = mergedDraft(aiDraft: result.draft, coverDraft: pendingCoverDraft)
        errorMessage = result.notice
    }

    private func mergedDraft(aiDraft: EchoMemoryDraft, coverDraft: EchoMemoryDraft?) -> EchoMemoryDraft {
        guard let coverDraft else { return aiDraft }

        let coverTitle = coverDraft.title.nilIfBlank
        let usesRealCoverTitle = coverTitle != nil && coverTitle != "Scanned Cover"

        return EchoMemoryDraft(
            title: usesRealCoverTitle ? coverDraft.title : aiDraft.title,
            creator: coverDraft.creator ?? aiDraft.creator,
            category: usesRealCoverTitle ? coverDraft.category : aiDraft.category,
            emotion: aiDraft.emotion,
            memory: aiDraft.memory,
            echoLine: aiDraft.echoLine,
            year: coverDraft.year ?? aiDraft.year,
            originalTranscript: aiDraft.originalTranscript,
            discoveryStatus: aiDraft.discoveryStatus
        )
    }
}

#Preview {
    CaptureView()
        .modelContainer(for: [EchoMemory.self, EchoMemoryStoredLink.self], inMemory: true)
}
