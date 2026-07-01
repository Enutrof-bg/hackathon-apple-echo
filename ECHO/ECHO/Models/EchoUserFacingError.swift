import Foundation

struct EchoUserFacingError: Identifiable {
    let id = UUID()
    let message: String

    static func persistenceFailure(action: String) -> EchoUserFacingError {
        EchoUserFacingError(
            message: "Echo could not \(action) right now. Your data is stored locally; try again in a moment."
        )
    }
}
