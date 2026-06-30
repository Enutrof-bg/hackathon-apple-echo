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
    case unavailable
    case failed(String)

    var statusText: String {
        switch self {
        case .idle: "Tap to record"
        case .requestingPermission: "Requesting permission..."
        case .ready: "Ready to record"
        case .listening: "Listening..."
        case .unavailable: "Speech recognition is unavailable."
        case .failed(let message): message
        }
    }

    var isListening: Bool {
        self == .listening
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
    private var analyzer: SpeechAnalyzer?
    private var transcriber: DictationTranscriber?
    private var captureInputProvider: CaptureInputSequenceProvider?
    private var analysisTask: Task<Void, Never>?
    private var resultTask: Task<Void, Never>?
    private var didStopIntentionally = false
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
            state = .failed(error.localizedDescription)
        }
    }

    func stopTranscribing() {
        guard captureInputProvider != nil || analyzer != nil else { return }

        didStopIntentionally = true
        state = .ready

        Task {
            await finishCurrentSession()
        }
    }

    func resetTranscript() {
        transcript = ""
    }

    func updateContextualStrings(_ strings: [String]) {
        contextualStrings = SpeechRecognitionContextProvider.normalizedContextualStrings(from: strings)
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
        didStopIntentionally = false

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

        self.analyzer = analyzer
        self.transcriber = transcriber
        self.captureInputProvider = captureInputProvider

        await captureSessionController.setCaptureSession(captureInputProvider.captureSession)
        startResultTask(for: transcriber)
        startAnalysisTask(with: analyzer, inputSequence: captureInputProvider.analyzerInputs)
        await captureSessionController.startRunning()
    }

    private func startResultTask(for transcriber: DictationTranscriber) {
        resultTask = Task { [weak self, transcriber] in
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    await MainActor.run {
                        self?.transcript = text
                    }
                }
            } catch {
                await MainActor.run {
                    guard let self, !self.didStopIntentionally else { return }
                    self.state = .failed(error.localizedDescription)
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
                    self.state = .failed(error.localizedDescription)
                }
            }

            await MainActor.run {
                guard let self else { return }
                self.clearAnalyzerReferences()
            }
        }
    }

    private func finishCurrentSession() async {
        await captureSessionController.stopRunning()
        captureInputProvider = nil
        transcriber = nil

        guard let analyzer else { return }

        do {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        } catch {
            guard !didStopIntentionally else { return }
            state = .failed(error.localizedDescription)
        }
    }

    private func cancelCurrentSession() async {
        await captureSessionController.stopRunning()
        captureInputProvider = nil
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
            "Speech recognition is unavailable. You can type your memory instead."
        case .microphonePermissionDenied:
            "Microphone permission is required to capture voice. You can type your memory instead."
        case .missingUsageDescription(let key):
            "Missing \(key) in the app Info settings. Add the privacy usage description in Xcode before recording."
        case .microphoneUnavailable:
            "Echo could not access a microphone on this device. You can type your memory instead."
        }
    }
}
