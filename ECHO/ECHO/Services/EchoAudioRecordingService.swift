import AVFAudio
import Foundation

struct EchoAudioAttachment {
    let fileName: String
    let duration: TimeInterval
}

enum EchoAudioFileService {
    nonisolated static func recordingURL(for fileName: String) throws -> URL {
        try recordingsDirectory().appendingPathComponent(fileName, isDirectory: false)
    }

    nonisolated static func deleteRecording(fileName: String?) {
        guard let fileName = cleanedFileName(fileName),
              let url = try? recordingURL(for: fileName) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    nonisolated static func fileExists(fileName: String?) -> Bool {
        guard let fileName = cleanedFileName(fileName),
              let url = try? recordingURL(for: fileName) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private nonisolated static func cleanedFileName(_ fileName: String?) -> String? {
        let cleanedFileName = fileName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return cleanedFileName.isEmpty ? nil : cleanedFileName
    }

    private nonisolated static func recordingsDirectory() throws -> URL {
        let fileManager = FileManager.default
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directoryURL = baseURL
            .appendingPathComponent("Echo", isDirectory: true)
            .appendingPathComponent("Recordings", isDirectory: true)

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }
}

final class EchoAudioRecordingService: NSObject {
    private let queue = DispatchQueue(label: "com.echo.audio-recording-service", qos: .userInitiated)
    private var recorder: AVAudioRecorder?
    private var currentFileName: String?
    private var currentFileURL: URL?
    private var recordingStartedAt: Date?

    func prepareRecording() async throws {
        try await performOnQueue {
            try self.prepareRecordingOnQueue()
        }
    }

    func startRecording() async {
        await performOnQueue {
            self.startRecordingOnQueue()
        }
    }

    func stopRecording() async -> EchoAudioAttachment? {
        await performOnQueue {
            self.stopRecordingOnQueue()
        }
    }

    func cancelRecordingAndDeleteFile() async {
        await performOnQueue {
            self.cancelRecordingAndDeleteFileOnQueue()
        }
    }

    private func prepareRecordingOnQueue() throws {
        cleanupPreparedRecording(deleteFile: false)

        let fileName = UUID().uuidString + ".m4a"
        let fileURL = try EchoAudioFileService.recordingURL(for: fileName)
        let recorder = try AVAudioRecorder(url: fileURL, settings: Self.recordingSettings)
        recorder.isMeteringEnabled = false
        recorder.prepareToRecord()

        self.recorder = recorder
        self.currentFileName = fileName
        self.currentFileURL = fileURL
    }

    private func startRecordingOnQueue() {
        guard let recorder, !recorder.isRecording else { return }
        recordingStartedAt = Date()
        recorder.record()
    }

    private func stopRecordingOnQueue() -> EchoAudioAttachment? {
        guard let recorder else {
            cleanupPreparedRecording(deleteFile: true)
            return nil
        }

        let measuredDuration = max(Date().timeIntervalSince(recordingStartedAt ?? Date()), recorder.currentTime)
        if recorder.isRecording {
            recorder.stop()
        }

        let attachment = makeAttachmentIfPossible(duration: measuredDuration)
        cleanupPreparedRecording(deleteFile: attachment == nil)
        return attachment
    }

    private func cancelRecordingAndDeleteFileOnQueue() {
        let fileName = currentFileName
        cleanupPreparedRecording(deleteFile: true)
        EchoAudioFileService.deleteRecording(fileName: fileName)
    }

    private func makeAttachmentIfPossible(duration: TimeInterval) -> EchoAudioAttachment? {
        guard let currentFileName,
              let currentFileURL,
              FileManager.default.fileExists(atPath: currentFileURL.path),
              duration > 0 else {
            return nil
        }

        return EchoAudioAttachment(fileName: currentFileName, duration: duration)
    }

    private func cleanupPreparedRecording(deleteFile: Bool) {
        if recorder?.isRecording == true {
            recorder?.stop()
        }

        if deleteFile {
            EchoAudioFileService.deleteRecording(fileName: currentFileName)
        }

        recorder = nil
        currentFileName = nil
        currentFileURL = nil
        recordingStartedAt = nil
    }

    private func performOnQueue<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func performOnQueue<T>(_ work: @escaping () -> T) async -> T {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: work())
            }
        }
    }

    private static var recordingSettings: [String: Any] {
        [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
    }
}

enum EchoAudioRecordingError: LocalizedError {
    case missingOutputFile

    var errorDescription: String? {
        switch self {
        case .missingOutputFile:
            "Echo could not prepare the voice recording file. You can still keep the transcript."
        }
    }
}
