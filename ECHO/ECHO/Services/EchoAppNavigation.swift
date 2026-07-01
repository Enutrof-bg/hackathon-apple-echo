import Foundation
import Observation

@MainActor
@Observable
final class EchoAppNavigation {
    static let shared = EchoAppNavigation()

    var captureRequestID = UUID()

    private init() {}

    func requestCapture() {
        captureRequestID = UUID()
    }
}
