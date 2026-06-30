import AVFoundation

actor SpeechCaptureSessionController {
    private var captureSession: AVCaptureSession?

    func setCaptureSession(_ captureSession: AVCaptureSession) {
        self.captureSession = captureSession
    }

    func startRunning() {
        guard let captureSession, !captureSession.isRunning else { return }
        captureSession.startRunning()
    }

    func stopRunning() {
        guard let captureSession else { return }

        if captureSession.isRunning {
            captureSession.stopRunning()
        }

        self.captureSession = nil
    }
}
