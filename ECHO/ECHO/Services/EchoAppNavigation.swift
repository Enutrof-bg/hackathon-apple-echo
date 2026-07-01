import Foundation
import Observation

@MainActor
@Observable
final class EchoAppNavigation {
    static let shared = EchoAppNavigation()

    var captureRequestID = UUID()
    var requestedCaptureMode: CaptureInputMode = .speech
    var shouldStartSpeechCapture = false

    var searchRequestID = UUID()
    var requestedSearchText = ""

    private init() {}

    func requestCapture(mode: CaptureInputMode = .speech, startSpeech: Bool = false) {
        requestedCaptureMode = mode
        shouldStartSpeechCapture = startSpeech
        captureRequestID = UUID()
    }

    func requestSearch(_ query: String) {
        requestedSearchText = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchRequestID = UUID()
    }
}
