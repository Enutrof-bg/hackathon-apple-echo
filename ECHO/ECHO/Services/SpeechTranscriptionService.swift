import AVFAudio
import AVFoundation
import Foundation
import Observation
import Speech

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

    private var modernSession: Any?
    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasLegacyAudioTap = false
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
        guard !isCapturing else { return }

        state = .requestingPermission

        do {
            try validatePrivacyUsageDescriptions()
            try await requestPermissions()

            #if canImport(FoundationModels, _version: 2.0)
            if #available(iOS 27.0, *) {
                try await startModernRecognitionSession()
            } else {
                try configureLegacySpeechRecognizerLocale()
                try await startLegacyRecognitionSession()
            }
            #else
            try configureLegacySpeechRecognizerLocale()
            try await startLegacyRecognitionSession()
            #endif

            state = .listening
        } catch {
            await cancelCurrentSession()
            state = .failed(Self.userFacingSpeechMessage(for: error))
        }
    }

    func stopTranscribing() {
        guard isCapturing else { return }

        didStopIntentionally = true
        state = .stopping

        Task {
            await finishCurrentSession()
        }
    }

    func finishTranscribingAndReturnTranscript() async -> String {
        guard isCapturing else { return transcript }

        didStopIntentionally = true
        state = .stopping
        await finishCurrentSession()
        try? await Task.sleep(for: .milliseconds(250))
        return transcript
    }

    func resetTranscript() {
        transcript = ""
        finalizedTranscriptParts = []
        volatileTranscriptPart = ""
    }

    func updateContextualStrings(_ strings: [String]) {
        contextualStrings = SpeechRecognitionContextProvider.normalizedContextualStrings(from: strings)
    }

    private var isCapturing: Bool {
        #if canImport(FoundationModels, _version: 2.0)
        if #available(iOS 27.0, *),
           let modernSession = modernSession as? ModernSpeechTranscriptionSession,
           modernSession.isCapturing {
            return true
        }
        #endif

        return audioEngine.isRunning || recognitionRequest != nil || recognitionTask != nil
    }

    #if canImport(FoundationModels, _version: 2.0)
    @available(iOS 27.0, *)
    private func startModernRecognitionSession() async throws {
        await cancelCurrentSession()
        didStopIntentionally = false
        resetTranscriptBuffers(keepingVisibleTranscript: !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        let session = ModernSpeechTranscriptionSession(
            contextualStrings: contextualStrings,
            onResult: { [weak self] text, isFinal in
                self?.applyTranscriptionResult(text, isFinal: isFinal)
            },
            onFailure: { [weak self] error in
                guard let self, !self.didStopIntentionally else { return }
                self.state = .failed(Self.userFacingSpeechMessage(for: error))
            },
            onFinish: { [weak self] in
                self?.modernSession = nil
            }
        )

        let locale = try await session.start(preferredLocale: recognitionLocale)
        recognitionLocale = locale
        recognitionLanguageName = SpeechRecognitionLocaleProvider.displayName(for: locale)
        modernSession = session
    }
    #endif

    private func configureLegacySpeechRecognizerLocale() throws {
        let locale = SpeechRecognitionLocaleProvider.automaticLocale()
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            state = .unavailable
            throw SpeechTranscriptionError.recognizerUnavailable
        }

        recognitionLocale = locale
        recognitionLanguageName = SpeechRecognitionLocaleProvider.displayName(for: locale)
        speechRecognizer = recognizer
    }

    private func validatePrivacyUsageDescriptions() throws {
        guard hasInfoPlistString(for: "NSMicrophoneUsageDescription") else {
            throw SpeechTranscriptionError.missingUsageDescription("NSMicrophoneUsageDescription")
        }

        guard hasInfoPlistString(for: "NSSpeechRecognitionUsageDescription") else {
            throw SpeechTranscriptionError.missingUsageDescription("NSSpeechRecognitionUsageDescription")
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

        let speechGranted = await requestSpeechRecognitionPermission()
        guard speechGranted else {
            throw SpeechTranscriptionError.speechRecognitionPermissionDenied
        }
    }

    private func startLegacyRecognitionSession() async throws {
        await cancelCurrentSession()
        didStopIntentionally = false
        resetTranscriptBuffers(keepingVisibleTranscript: !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        let recognizer = try resolvedLegacySpeechRecognizer()
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.contextualStrings = contextualStrings

        recognitionRequest = request
        speechRecognizer = recognizer

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            throw SpeechTranscriptionError.microphoneUnavailable
        }

        removeLegacyAudioTapIfNeeded()
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }
        hasLegacyAudioTap = true

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    self.applyTranscriptionResult(result.bestTranscription.formattedString, isFinal: result.isFinal)

                    if result.isFinal {
                        self.stopLegacyAudioCapture()
                        self.clearLegacyRecognitionReferences()
                        self.state = .ready
                    }
                }

                if let error, !self.didStopIntentionally {
                    self.cancelLegacyRecognitionSession()
                    self.state = .failed(Self.userFacingSpeechMessage(for: error))
                }
            }
        }
    }

    private func resolvedLegacySpeechRecognizer() throws -> SFSpeechRecognizer {
        if let speechRecognizer, speechRecognizer.isAvailable {
            return speechRecognizer
        }

        guard let recognizer = SFSpeechRecognizer(locale: recognitionLocale), recognizer.isAvailable else {
            state = .unavailable
            throw SpeechTranscriptionError.recognizerUnavailable
        }

        return recognizer
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

    private func finishCurrentSession() async {
        if isLegacyRecognitionActive {
            finishLegacyRecognitionSession()
        }

        #if canImport(FoundationModels, _version: 2.0)
        if #available(iOS 27.0, *),
           let session = modernSession as? ModernSpeechTranscriptionSession {
            do {
                try await session.finish()
                modernSession = nil
                state = .ready
            } catch {
                guard !didStopIntentionally else {
                    modernSession = nil
                    state = .ready
                    return
                }
                state = .failed(Self.userFacingSpeechMessage(for: error))
            }
            return
        }
        #endif

        state = .ready
    }

    private func cancelCurrentSession() async {
        if isLegacyRecognitionActive {
            cancelLegacyRecognitionSession()
        }

        #if canImport(FoundationModels, _version: 2.0)
        if #available(iOS 27.0, *),
           let session = modernSession as? ModernSpeechTranscriptionSession {
            await session.cancel()
            modernSession = nil
        }
        #endif
    }

    private func finishLegacyRecognitionSession() {
        stopLegacyAudioCapture()
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        clearLegacyRecognitionReferences()
    }

    private func cancelLegacyRecognitionSession() {
        stopLegacyAudioCapture()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        clearLegacyRecognitionReferences()
    }

    private func stopLegacyAudioCapture() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        removeLegacyAudioTapIfNeeded()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private var isLegacyRecognitionActive: Bool {
        audioEngine.isRunning || hasLegacyAudioTap || recognitionRequest != nil || recognitionTask != nil
    }

    private func removeLegacyAudioTapIfNeeded() {
        guard hasLegacyAudioTap else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        hasLegacyAudioTap = false
    }

    private func clearLegacyRecognitionReferences() {
        recognitionRequest = nil
        recognitionTask = nil
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

    private func requestSpeechRecognitionPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

#if canImport(FoundationModels, _version: 2.0)
@available(iOS 27.0, *)
@MainActor
private final class ModernSpeechTranscriptionSession {
    private let captureSessionController = SpeechCaptureSessionController()
    private var analyzer: SpeechAnalyzer?
    private var transcriber: DictationTranscriber?
    private var captureInputProvider: CaptureInputSequenceProvider?
    private var analysisTask: Task<Void, Never>?
    private var resultTask: Task<Void, Never>?
    private var didStopIntentionally = false
    private let contextualStrings: [String]
    private let onResult: (String, Bool) -> Void
    private let onFailure: (Error) -> Void
    private let onFinish: () -> Void

    init(
        contextualStrings: [String],
        onResult: @escaping (String, Bool) -> Void,
        onFailure: @escaping (Error) -> Void,
        onFinish: @escaping () -> Void
    ) {
        self.contextualStrings = contextualStrings
        self.onResult = onResult
        self.onFailure = onFailure
        self.onFinish = onFinish
    }

    var isCapturing: Bool {
        captureInputProvider != nil || analyzer != nil
    }

    func start(preferredLocale: Locale) async throws -> Locale {
        didStopIntentionally = false

        guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: preferredLocale)
            ?? SpeechRecognitionLocaleProvider.automaticDictationLocale() else {
            throw SpeechTranscriptionError.recognizerUnavailable
        }

        let transcriber = DictationTranscriber(locale: locale, preset: .progressiveLongDictation)
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

        self.analyzer = analyzer
        self.transcriber = transcriber
        self.captureInputProvider = captureInputProvider

        await captureSessionController.setCaptureSession(captureInputProvider.captureSession)
        startResultTask(for: transcriber)
        startAnalysisTask(with: analyzer, inputSequence: captureInputProvider.analyzerInputs)
        await captureSessionController.startRunning()

        return locale
    }

    func finish() async throws {
        didStopIntentionally = true
        await captureSessionController.stopRunning()
        captureInputProvider = nil
        transcriber = nil

        guard let analyzer else {
            clearReferences()
            return
        }

        try await analyzer.finalizeAndFinishThroughEndOfInput()
        clearReferences()
    }

    func cancel() async {
        didStopIntentionally = true
        await captureSessionController.stopRunning()
        captureInputProvider = nil
        resultTask?.cancel()
        analysisTask?.cancel()
        resultTask = nil
        analysisTask = nil

        let analyzerToCancel = analyzer
        clearReferences()

        if let analyzerToCancel {
            await analyzerToCancel.cancelAndFinishNow()
        }
    }

    private func startResultTask(for transcriber: DictationTranscriber) {
        resultTask = Task { [weak self, transcriber] in
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    let isFinal = result.isFinal
                    await MainActor.run {
                        self?.onResult(text, isFinal)
                    }
                }
            } catch {
                await MainActor.run {
                    guard let self, !self.didStopIntentionally else { return }
                    self.onFailure(error)
                }
            }
        }
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
                    self.onFailure(error)
                }
            }

            await MainActor.run {
                self?.clearReferences()
                self?.onFinish()
            }
        }
    }

    private func clearReferences() {
        analyzer = nil
        transcriber = nil
        captureInputProvider = nil
        analysisTask = nil
        resultTask = nil
    }
}
#endif

enum SpeechTranscriptionError: LocalizedError {
    case recognizerUnavailable
    case microphonePermissionDenied
    case speechRecognitionPermissionDenied
    case missingUsageDescription(String)
    case microphoneUnavailable

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            "Speech recognition is not available for your current device or language. Switch to Type mode to keep creating this Echo."
        case .microphonePermissionDenied:
            "Microphone access is off for Echo. Enable it in Settings, or switch to Type mode to keep creating this Echo."
        case .speechRecognitionPermissionDenied:
            "Speech recognition access is off for Echo. Enable it in Settings, or switch to Type mode to keep creating this Echo."
        case .missingUsageDescription(let key):
            "Missing \(key) in the app Info settings. Add the privacy usage description in Xcode before recording."
        case .microphoneUnavailable:
            "Echo could not find a usable microphone on this device. Switch to Type mode to keep creating this Echo."
        }
    }
}
