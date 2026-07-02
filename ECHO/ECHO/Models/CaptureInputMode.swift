import Foundation

enum CaptureInputMode: String, CaseIterable, Identifiable {
    case speech
    case text
    case camera

    var id: String { rawValue }

    static var availableCases: [CaptureInputMode] {
        if cameraCaptureIsAvailable {
            return allCases
        }

        return [.speech, .text]
    }

    static var cameraCaptureIsAvailable: Bool {
        if #available(iOS 27.0, *) {
            return true
        }

        return false
    }

    var supportedMode: CaptureInputMode {
        self == .camera && !Self.cameraCaptureIsAvailable ? .speech : self
    }

    var title: String {
        switch self {
        case .speech: "Speak"
        case .text: "Type"
        case .camera: "Camera"
        }
    }
}
