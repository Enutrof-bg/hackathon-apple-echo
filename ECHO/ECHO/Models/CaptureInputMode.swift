import Foundation

enum CaptureInputMode: String, CaseIterable, Identifiable {
    case speech
    case text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .speech: "Speak"
        case .text: "Type"
        }
    }
}
