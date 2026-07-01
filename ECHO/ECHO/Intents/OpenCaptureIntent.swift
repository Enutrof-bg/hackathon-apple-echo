import AppIntents
import Foundation

struct OpenCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "Capture an Echo"
    static var description = IntentDescription("Open Echo capture to record, type, or scan a memory.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        EchoAppNavigation.shared.requestCapture()
        return .result(dialog: "Opening Echo capture.")
    }
}
