import SwiftData
import SwiftUI
import UIKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EchoMemory.createdAt, order: .reverse) private var memories: [EchoMemory]

    @State private var isShowingTextInput = false
    @State private var isShowingCamera = false
    @State private var isShowingCreatedEcho = false
    @State private var selectedMemory: EchoMemory?
    @State private var navigation = EchoAppNavigation.shared
    @State private var handledCaptureRequestID = EchoAppNavigation.shared.captureRequestID
    @State private var handledSearchRequestID = EchoAppNavigation.shared.searchRequestID
    @State private var pendingSearchText = ""
    @State private var transcriptionService = SpeechTranscriptionService()
    @State private var isCreatingEcho = false
    @State private var statusMessage: String?
    @State private var captureError: EchoUserFacingError?
#if DEBUG
    @State private var isLoadingSampleEchoes = false
    @State private var isRebuildingLinks = false
#endif

    private let persistenceService = EchoMemoryPersistenceService()
    private let extractionService = AIExtractionService()
    private let coverScanService = EchoCoverScanService()
    private let linkService = EchoMemoryLinkService()
#if DEBUG
    private let placeholderService = EchoPlaceholderService()
#endif

    private var activeMemories: [EchoMemory] {
        memories.filter { $0.deletedAt == nil }
    }

    private var centralButtonState: ScribbleEchoButtonState {
        transcriptionService.state.isListening || transcriptionService.state.isStopping || isCreatingEcho ? .recording : .idle
    }

    private var inputControlsAreDisabled: Bool {
        isCreatingEcho || transcriptionService.state.isStopping
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EchoStyle.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    Spacer()

                    VStack(spacing: 28) {
                        captureButton
                        inputOptions
                        captureCaption
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 20)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isShowingCreatedEcho) {
                if let selectedMemory {
                    EchoDetailView(
                        memory: selectedMemory,
                        candidateMemories: activeMemories,
                        startsEditing: true
                    )
                }
            }
            .sheet(isPresented: $isShowingTextInput) {
                TextEchoInputSheet(isProcessing: isCreatingEcho) { text in
                    await createEcho(from: text)
                }
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.scrolls)
                .interactiveDismissDisabled(isCreatingEcho)
            }
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraImagePicker(sourceType: .camera) { image in
                    isShowingCamera = false
                    Task {
                        await createEcho(fromCoverImage: image)
                    }
                } onCancel: {
                    isShowingCamera = false
                }
                .ignoresSafeArea()
            }
            .task {
                purgeExpiredDeletedMemoriesIfNeeded()
            }
            .onChange(of: navigation.captureRequestID) { _, requestID in
                guard requestID != handledCaptureRequestID else { return }
                handledCaptureRequestID = requestID
                handleCaptureRequest(
                    mode: navigation.requestedCaptureMode,
                    startSpeech: navigation.shouldStartSpeechCapture
                )
            }
            .onChange(of: navigation.searchRequestID) { _, requestID in
                guard requestID != handledSearchRequestID else { return }
                handledSearchRequestID = requestID
                pendingSearchText = navigation.requestedSearchText
            }
            .alert(item: $captureError) { error in
                Alert(
                    title: Text("Echo could not be created"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onDisappear {
                transcriptionService.stopTranscribing()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Echo")
                    .font(.title2)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(0.4)

                Spacer()
            }

            Rectangle()
                .fill(EchoStyle.border)
                .frame(height: 1)
        }
    }

    private var captureButton: some View {
        ScribbleEchoButton(state: centralButtonState, size: 190) {
            Task {
                await toggleVoiceCapture()
            }
        }
        .disabled(inputControlsAreDisabled && !transcriptionService.state.isListening)
        .accessibilityHint(transcriptionService.state.isListening ? "Double tap to finish voice capture and create an Echo." : "Double tap to record on the home screen.")
    }

    private var inputOptions: some View {
        HStack(spacing: 78) {
            inputOption("Text", systemImage: "textformat") {
                guard !inputControlsAreDisabled else { return }
                statusMessage = nil
                isShowingTextInput = true
            }

            if CaptureInputMode.cameraCaptureIsAvailable {
                inputOption("Photo", systemImage: "camera") {
                    guard !inputControlsAreDisabled else { return }
                    statusMessage = nil
                    isShowingCamera = true
                }
            }
        }
    }

    private func inputOption(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(width: 54, height: 54)
                    .background(EchoStyle.surface)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(EchoStyle.border.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 5)

                Text(title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(EchoStyle.ink)
            }
        }
        .buttonStyle(.plain)
        .disabled(inputControlsAreDisabled)
        .accessibilityLabel(title == "Photo" ? "Scan a cover" : "Type an Echo")
        .accessibilityHint(title == "Photo" ? "Double tap to open camera capture immediately." : "Double tap to type a memory in a compact editor.")
    }

    private var captureCaption: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(EchoStyle.border.opacity(0.7))
                    .frame(width: 56, height: 1)

                Text(captionTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .tracking(1)

                Rectangle()
                    .fill(EchoStyle.border.opacity(0.7))
                    .frame(width: 56, height: 1)
            }

            Text(captionMessage)
                .font(.footnote)
                .foregroundStyle(EchoStyle.mutedInk)
                .multilineTextAlignment(.center)
        }
    }

    private var captionTitle: String {
        if transcriptionService.state.isListening { return "Listening" }
        if transcriptionService.state.isStopping || isCreatingEcho { return "Creating Echo" }
        return "Capture an Echo"
    }

    private var captionMessage: String {
        if let statusMessage { return statusMessage }
        if case .failed(let message) = transcriptionService.state { return message }
        if transcriptionService.state.isListening { return "Tap the center again when you are done. Echo will shape the card privately." }
        if transcriptionService.state.isStopping { return "Finishing the recording before Apple Intelligence shapes the card." }
        if isCreatingEcho { return "Apple Intelligence is shaping the card. You will edit it next." }
        if CaptureInputMode.cameraCaptureIsAvailable {
            return "Speak, type, or take a photo\nof a work that matters to you."
        }
        return "Speak or type a memory\nof a work that matters to you."
    }

    private func handleCaptureRequest(mode: CaptureInputMode, startSpeech: Bool) {
        switch mode.supportedMode {
        case .speech:
            if startSpeech {
                Task { await startVoiceCapture() }
            } else {
                Task { await toggleVoiceCapture() }
            }
        case .text:
            isShowingTextInput = true
        case .camera:
            isShowingCamera = true
        }
    }

    private func toggleVoiceCapture() async {
        if transcriptionService.state.isListening {
            await finishVoiceCapture()
        } else {
            await startVoiceCapture()
        }
    }

    private func startVoiceCapture() async {
        guard !isCreatingEcho else { return }
        statusMessage = nil
        transcriptionService.resetTranscript()
        transcriptionService.updateContextualStrings(
            SpeechRecognitionContextProvider.contextualStrings(from: activeMemories)
        )
        await transcriptionService.startTranscribing()
    }

    private func finishVoiceCapture() async {
        guard !isCreatingEcho else { return }
        isCreatingEcho = true
        statusMessage = "Finishing the recording before Apple Intelligence shapes the card."
        let captureResult = await transcriptionService.finishTranscribingAndReturnCapture()
        let transcript = captureResult.transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !transcript.isEmpty else {
            EchoAudioFileService.deleteRecording(fileName: captureResult.audioAttachment?.fileName)
            statusMessage = "Echo did not catch enough speech. Try again or use text."
            isCreatingEcho = false
            return
        }

        let result = await extractionService.createDraftResult(from: transcript)
        var draft = result.draft
        draft.audioFileName = captureResult.audioAttachment?.fileName
        draft.audioDuration = captureResult.audioAttachment?.duration
        await saveAndOpen(draft, notice: result.notice)
    }

    private func createEcho(from text: String) async {
        guard !isCreatingEcho else { return }
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else {
            statusMessage = "Type a memory before creating an Echo."
            return
        }

        isCreatingEcho = true
        statusMessage = "Apple Intelligence is shaping the card. You will edit it next."
        let result = await extractionService.createDraftResult(from: cleanedText)
        await saveAndOpen(result.draft, notice: result.notice)
    }

    private func createEcho(fromCoverImage image: UIImage) async {
        guard !isCreatingEcho else { return }
        isCreatingEcho = true
        statusMessage = "Apple Intelligence is reading the photo. You will edit the card next."
        let result = await coverScanService.scanCover(from: image)
        let draft = photoDraft(from: result)
        await saveAndOpen(draft, notice: notice(for: result.source))
    }

    private func photoDraft(from result: EchoCoverScanResult) -> EchoMemoryDraft {
        var draft = result.draft
        if draft.memory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.memory = result.visibleText.nilIfBlank ?? "A work I want to discover."
        }
        return draft
    }

    private func saveAndOpen(_ draft: EchoMemoryDraft, notice: String?) async {
        do {
            let savedMemory = try persistenceService.insert(draft, in: modelContext)
            try? linkService.createAndStoreLinks(for: savedMemory, among: activeMemories, in: modelContext)
            selectedMemory = savedMemory
            statusMessage = notice
            isCreatingEcho = false
            isShowingTextInput = false
            isShowingCreatedEcho = true
        } catch {
            EchoAudioFileService.deleteRecording(fileName: draft.audioFileName)
            captureError = .persistenceFailure(action: "save this Echo")
            isCreatingEcho = false
        }
    }

    private func notice(for source: EchoCoverScanSource) -> String? {
        switch source {
        case .appleIntelligence:
            return nil
        case .visionOCR:
            return "Apple Intelligence image scan was unavailable. Echo used local OCR instead."
        case .manualFallback:
            return "Echo could not read this photo automatically. The edit screen is ready for manual correction."
        }
    }

#if DEBUG
    private func insertPlaceholderEchoes() {
        guard !isLoadingSampleEchoes else { return }
        isLoadingSampleEchoes = true

        Task {
            defer { isLoadingSampleEchoes = false }

            do {
                try await placeholderService.insertPlaceholders(in: modelContext, existingMemories: memories)
            } catch {
                captureError = .persistenceFailure(action: "update the local collection")
            }
        }
    }

    private func rebuildEchoLinks() {
        guard !isRebuildingLinks else { return }
        isRebuildingLinks = true

        Task {
            defer { isRebuildingLinks = false }

            do {
                try linkService.rebuildStoredLinks(for: activeMemories, in: modelContext)
            } catch {
                captureError = .persistenceFailure(action: "update the local collection")
            }
        }
    }
#endif

    private func purgeExpiredDeletedMemoriesIfNeeded() {
        do {
            try persistenceService.purgeExpiredDeletedMemories(memories, in: modelContext)
        } catch {
            captureError = .persistenceFailure(action: "update the local collection")
        }
    }
}

private struct TextEchoInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEditorFocused: Bool

    let isProcessing: Bool
    let onSubmit: (String) async -> Void

    @State private var text = ""

    private var canSubmit: Bool {
        !isProcessing && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Text Echo")
                        .font(.headline)
                        .foregroundStyle(EchoStyle.ink)

                    TextEditor(text: $text)
                        .focused($isEditorFocused)
                        .frame(minHeight: 170)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(EchoStyle.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(EchoStyle.border.opacity(0.22), lineWidth: 1)
                        )
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel("Echo text")
                        .accessibilityHint("Write the memory or work to turn into an Echo card.")
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(EchoStyle.background)
            .navigationTitle("Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isEditorFocused = false
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task {
                        isEditorFocused = false
                        await onSubmit(text)
                    }
                } label: {
                    Label(isProcessing ? "Creating Echo..." : "Create Echo", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .echoGlassButtonStyle(prominent: true)
                .controlSize(.large)
                .disabled(!canSubmit)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .background(.thinMaterial)
            }
            .task {
                isEditorFocused = true
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [EchoMemory.self, EchoMemoryStoredLink.self], inMemory: true)
}
