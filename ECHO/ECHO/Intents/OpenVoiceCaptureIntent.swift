import AppIntents
import Foundation

struct OpenVoiceCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Voice Echo"
    static var description = IntentDescription("Open Echo capture and start listening immediately.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        EchoAppNavigation.shared.requestCapture(mode: .speech, startSpeech: true)
        return .result(dialog: "Listening for a new Echo.")
    }
}
