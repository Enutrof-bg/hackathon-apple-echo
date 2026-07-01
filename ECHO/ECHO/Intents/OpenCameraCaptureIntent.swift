import AppIntents
import Foundation

struct OpenCameraCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "Scan Echo Cover"
    static var description = IntentDescription("Open Echo capture on the camera mode to scan a cover.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        EchoAppNavigation.shared.requestCapture(mode: .camera)
        return .result(dialog: "Opening camera capture.")
    }
}
