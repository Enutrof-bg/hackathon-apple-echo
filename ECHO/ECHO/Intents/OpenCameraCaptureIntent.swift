import AppIntents
import Foundation

struct OpenCameraCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "Scan Echo Cover"
    static var description = IntentDescription("Open Echo capture on the camera mode to scan a cover.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard CaptureInputMode.cameraCaptureIsAvailable else {
            EchoAppNavigation.shared.requestCapture(mode: .speech)
            return .result(dialog: "Camera scan is available on iOS 27 or later. Opening voice capture instead.")
        }

        EchoAppNavigation.shared.requestCapture(mode: .camera)
        return .result(dialog: "Opening camera capture.")
    }
}
