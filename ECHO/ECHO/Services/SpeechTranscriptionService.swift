import AVFAudio
import AVFoundation
import Foundation
import Observation
import Speech

struct SpeechCaptureResult {
    let transcript: String
    let audioAttachment: EchoAudioAttachment?
}

enum SpeechCaptureState: Equatable {
    case idle
    case requestingPermission
    case ready
    case listening
    case stopping
    case unavailable
    case failed(String)

    var statusText: String {
        switch self {
        case .idle: "Tap to record"
        case .requestingPermission: "Requesting permission..."
        case .ready: "Ready to record"
        case .listening: "Listening..."
        case .stopping: "Finishing recording..."
        case .unavailable: "Speech recognition is unavailable."
        case .failed(let message): message
        }
    }

    var isListening: Bool {
        self == .listening
    }

    var isStopping: Bool {
        self == .stopping
    }
}

@MainActor
@Observable
final class SpeechTranscriptionService {
    var transcript = ""
    var state: SpeechCaptureState = .idle
    private(set) var recognitionLocale: Locale
    private(set) var recognitionLanguageName: String

    private let captureSessionController = SpeechCaptureSessionController()
    private let audioRecordingService = EchoAudioRecordingService()
    private var analyzer: SpeechAnalyzer?
    private var transcriber: DictationTranscriber?
    private var captureInputProvider: CaptureInputSequenceProvider?
    private var analysisTask: Task<Void, Never>?
    private var resultTask: Task<Void, Never>?
    private var finishTask: Task<Void, Never>?
    private var recordedAudioAttachment: EchoAudioAttachment?
    private var didStopIntentionally = false
    private var finalizedTranscriptParts: [String] = []
    private var volatileTranscriptPart = ""
    private var contextualStrings: [String]

    init(
        locale: Locale? = nil,
        contextualStrings: [String]? = nil
    ) {
        let resolvedLocale = locale ?? SpeechRecognitionLocaleProvider.automaticLocale()
        let resolvedContextualStrings = contextualStrings ?? SpeechRecognitionContextProvider.defaultCulturalTerms
        self.recognitionLocale = resolvedLocale
        self.recognitionLanguageName = SpeechRecognitionLocaleProvider.displayName(for: resolvedLocale)
        self.contextualStrings = SpeechRecognitionContextProvider.normalizedContextualStrings(from: resolvedContextualStrings)
    }

    func startTranscribing() async {
        guard captureInputProvider == nil else { return }

        state = .requestingPermission

        do {
            try validatePrivacyUsageDescriptions()
            try await configureAutomaticDictationLocale()
            try await requestPermissions()
            try await startAnalyzerSession()
            state = .listening
        } catch {
            await cancelCurrentSession()
            state = .failed(Self.userFacingSpeechMessage(for: error))
        }
    }

    func stopTranscribing() {
        guard captureInputProvider != nil || analyzer != nil else { return }

        didStopIntentionally = true
        state = .stopping

        if finishTask == nil {
            finishTask = Task { [weak self] in
                await self?.finishCurrentSession()
            }
        }
    }

    func finishTranscribingAndReturnTranscript() async -> String {
        await finishTranscribingAndReturnCapture().transcript
    }

    func finishTranscribingAndReturnCapture() async -> SpeechCaptureResult {
        if let finishTask {
            await finishTask.value
            return SpeechCaptureResult(transcript: transcript, audioAttachment: takeRecordedAudioAttachment())
        }

        guard captureInputProvider != nil || analyzer != nil else {
            return SpeechCaptureResult(transcript: transcript, audioAttachment: takeRecordedAudioAttachment())
        }

        didStopIntentionally = true
        state = .stopping
        await finishCurrentSession()
        try? await Task.sleep(for: .milliseconds(250))
        return SpeechCaptureResult(transcript: transcript, audioAttachment: takeRecordedAudioAttachment())
    }

    func resetTranscript() {
        transcript = ""
        finalizedTranscriptParts = []
        volatileTranscriptPart = ""
        EchoAudioFileService.deleteRecording(fileName: recordedAudioAttachment?.fileName)
        recordedAudioAttachment = nil
    }

    func updateContextualStrings(_ strings: [String]) {
        contextualStrings = SpeechRecognitionContextProvider.normalizedContextualStrings(from: strings)
    }

    private func takeRecordedAudioAttachment() -> EchoAudioAttachment? {
        let attachment = recordedAudioAttachment
        recordedAudioAttachment = nil
        return attachment
    }

    private func configureAutomaticDictationLocale() async throws {
        guard let locale = await SpeechRecognitionLocaleProvider.automaticDictationLocale() else {
            state = .unavailable
            throw SpeechTranscriptionError.recognizerUnavailable
        }

        recognitionLocale = locale
        recognitionLanguageName = SpeechRecognitionLocaleProvider.displayName(for: locale)
    }

    private func validatePrivacyUsageDescriptions() throws {
        guard hasInfoPlistString(for: "NSMicrophoneUsageDescription") else {
            throw SpeechTranscriptionError.missingUsageDescription("NSMicrophoneUsageDescription")
        }
    }

    private func hasInfoPlistString(for key: String) -> Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return false
        }

        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func requestPermissions() async throws {
        let microphoneGranted = await requestMicrophonePermission()
        guard microphoneGranted else {
            throw SpeechTranscriptionError.microphonePermissionDenied
        }
    }

    private func startAnalyzerSession() async throws {
        await cancelCurrentSession()
        EchoAudioFileService.deleteRecording(fileName: recordedAudioAttachment?.fileName)
        recordedAudioAttachment = nil
        finishTask = nil
        didStopIntentionally = false
        resetTranscriptBuffers(keepingVisibleTranscript: !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        let transcriber = DictationTranscriber(locale: recognitionLocale, preset: .progressiveLongDictation)
        let modules: [any SpeechModule] = [transcriber]

        if let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: modules) {
            try await installationRequest.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: modules)
        let analysisContext = SpeechRecognitionContextProvider.makeAnalysisContext(from: contextualStrings)
        try await analyzer.setContext(analysisContext)

        guard let captureDevice = AVCaptureDevice.default(.microphone, for: .audio, position: .unspecified) else {
            throw SpeechTranscriptionError.microphoneUnavailable
        }

        let captureInputProvider = try await CaptureInputSequenceProvider.providerWithSession(
            from: captureDevice,
            compatibleWith: modules,
            priority: .userInitiated
        )

        try audioRecordingService.prepareRecording()

        self.analyzer = analyzer
        self.transcriber = transcriber
        self.captureInputProvider = captureInputProvider

        await captureSessionController.setCaptureSession(captureInputProvider.captureSession)
        startResultTask(for: transcriber)
        startAnalysisTask(with: analyzer, inputSequence: captureInputProvider.analyzerInputs)
        await captureSessionController.startRunning()
        audioRecordingService.startRecording()
    }

    private func startResultTask(for transcriber: DictationTranscriber) {
        resultTask = Task { [weak self, transcriber] in
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    let isFinal = result.isFinal
                    await MainActor.run {
                        self?.applyTranscriptionResult(text, isFinal: isFinal)
                    }
                }
            } catch {
                await MainActor.run {
                    guard let self, !self.didStopIntentionally else { return }
                    self.state = .failed(Self.userFacingSpeechMessage(for: error))
                }
            }
        }
    }

    fileprivate func applyTranscriptionResult(_ text: String, isFinal: Bool) {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else { return }

        if isFinal {
            appendFinalTranscriptPart(cleanedText)
            volatileTranscriptPart = ""
        } else {
            volatileTranscriptPart = cleanedText
        }

        transcript = composedTranscript
    }

    private func appendFinalTranscriptPart(_ text: String) {
        if finalizedTranscriptParts.last == text { return }
        finalizedTranscriptParts.append(text)
    }

    private var composedTranscript: String {
        (finalizedTranscriptParts + [volatileTranscriptPart])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    fileprivate func resetTranscriptBuffers(keepingVisibleTranscript: Bool) {
        finalizedTranscriptParts = keepingVisibleTranscript ? [transcript.trimmingCharacters(in: .whitespacesAndNewlines)].filter { !$0.isEmpty } : []
        volatileTranscriptPart = ""
    }

    private func startAnalysisTask<InputSequence>(
        with analyzer: SpeechAnalyzer,
        inputSequence: InputSequence
    ) where InputSequence: AsyncSequence & Sendable, InputSequence.Element == AnalyzerInput {
        analysisTask = Task { [weak self, analyzer, inputSequence] in
            do {
                let lastSampleTime = try await analyzer.analyzeSequence(inputSequence)

                if let lastSampleTime {
                    try await analyzer.finalizeAndFinish(through: lastSampleTime)
                } else {
                    await analyzer.cancelAndFinishNow()
                }
            } catch {
                await MainActor.run {
                    guard let self, !self.didStopIntentionally else { return }
                    self.state = .failed(Self.userFacingSpeechMessage(for: error))
                }
            }

            await MainActor.run {
                guard let self else { return }
                self.clearAnalyzerReferences()
            }
        }
    }

    private func finishCurrentSession() async {
        let audioAttachment = await audioRecordingService.stopRecording()
        recordedAudioAttachment = audioAttachment
        await captureSessionController.stopRunning()
        captureInputProvider = nil
        transcriber = nil
        finishTask = nil

        guard let analyzer else {
            state = .ready
            return
        }

        do {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
            state = .ready
        } catch {
            guard !didStopIntentionally else {
                state = .ready
                return
            }
            state = .failed(Self.userFacingSpeechMessage(for: error))
        }
    }

    private func cancelCurrentSession() async {
        await audioRecordingService.cancelRecordingAndDeleteFile()
        await captureSessionController.stopRunning()
        captureInputProvider = nil
        finishTask = nil
        resultTask?.cancel()
        analysisTask?.cancel()
        resultTask = nil
        analysisTask = nil

        let analyzerToCancel = analyzer
        analyzer = nil
        transcriber = nil

        if let analyzerToCancel {
            await analyzerToCancel.cancelAndFinishNow()
        }
    }

    private func clearAnalyzerReferences() {
        analyzer = nil
        transcriber = nil
        captureInputProvider = nil
        analysisTask = nil
        resultTask = nil
    }

    private static func userFacingSpeechMessage(for error: Error) -> String {
        if let speechError = error as? SpeechTranscriptionError,
           let message = speechError.errorDescription {
            return message
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "Speech assets could not be downloaded right now. Check your connection, or type your memory instead."
        }

        if nsError.domain == AVFoundationErrorDomain {
            return "Echo could not start microphone capture. Check microphone access, or type your memory instead."
        }

        return "Speech capture stopped unexpectedly. You can try recording again or switch to Type mode."
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

enum SpeechTranscriptionError: LocalizedError {
    case recognizerUnavailable
    case microphonePermissionDenied
    case missingUsageDescription(String)
    case microphoneUnavailable

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            "Speech recognition is not available for your current device or language. Switch to Type mode to keep creating this Echo."
        case .microphonePermissionDenied:
            "Microphone access is off for Echo. Enable it in Settings, or switch to Type mode to keep creating this Echo."
        case .missingUsageDescription(let key):
            "Missing \(key) in the app Info settings. Add the privacy usage description in Xcode before recording."
        case .microphoneUnavailable:
            "Echo could not find a usable microphone on this device. Switch to Type mode to keep creating this Echo."
        }
    }
}
