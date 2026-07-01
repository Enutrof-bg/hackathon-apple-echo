import Foundation
import FoundationModels
import UIKit
import Vision

struct EchoCoverScanService {
    private let titleExtractionService = EchoTitleExtractionService()

    func scanCover(from image: UIImage) async -> EchoCoverScanResult {
        #if canImport(FoundationModels, _version: 2.0)
        if #available(iOS 27.0, *),
           let result = try? await scanWithAppleIntelligence(image: image) {
            return result
        }
        #endif

        if let result = try? await scanWithVisionOCR(image: image) {
            return result
        }

        return EchoCoverScanResult(
            title: nil,
            creator: nil,
            year: nil,
            category: .book,
            confidence: .low,
            visibleText: "",
            source: .manualFallback
        )
    }

    #if canImport(FoundationModels, _version: 2.0)
    @available(iOS 27.0, *)
    private func scanWithAppleIntelligence(image: UIImage) async throws -> EchoCoverScanResult {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw EchoCoverScanError.appleIntelligenceUnavailable
        }

        let session = LanguageModelSession(
            model: model,
            instructions: """
            Extract metadata from photographed cultural work covers for Echo.
            Use only text or visual evidence visible in the image. Do not invent facts.
            Prefer nil over guessing. If unsure whether the work is a book, film, album, game, painting, performance, place, object, or other, choose the best visible category.
            Return concise values suitable for a review form.
            """
        )

        let response = try await session.respond(generating: GeneratedEchoCoverScan.self) {
            """
            Analyze this cover image and extract one Echo card metadata draft.

            Rules:
            - title: the main work title only, not the subtitle unless it is required to identify the work.
            - creator: author, director, artist, musician, studio, or creator only when visible or extremely certain from the cover.
            - year: explicit four-digit year only when visible.
            - visibleText: short transcription of the most useful text visible on the cover.
            - confidence: high only when title and creator/year/category are clearly supported by the image.
            """

            Attachment(image)
                .label("cover")
        }

        return response.content.makeResult(source: .appleIntelligence)
    }
    #endif

    private func scanWithVisionOCR(image: UIImage) async throws -> EchoCoverScanResult {
        guard let cgImage = image.cgImage else {
            throw EchoCoverScanError.invalidImage
        }

        let recognizedText = try await recognizeText(in: cgImage)
        let cleanedText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else {
            throw EchoCoverScanError.noRecognizedText
        }

        let titleCandidate = titleExtractionService.extractTitleCandidate(from: "je veux lire \(cleanedText)")
        let lines = cleanedText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let title = titleCandidate?.title ?? bestTitleLine(from: lines)
        let creator = titleCandidate?.creator ?? bestCreatorLine(from: lines, excluding: title)

        return EchoCoverScanResult(
            title: title,
            creator: creator,
            year: extractYear(from: cleanedText),
            category: .book,
            confidence: title == nil ? .low : .medium,
            visibleText: cleanedText,
            source: .visionOCR
        )
    }

    private func recognizeText(in cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["fr-FR", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func bestTitleLine(from lines: [String]) -> String? {
        lines
            .filter { !$0.isLikelyCreatorCredit }
            .max { lhs, rhs in lhs.coverTitleScore < rhs.coverTitleScore }
            .map(normalizedCoverText)
            .flatMap(\ .nilIfBlank)
    }

    private func bestCreatorLine(from lines: [String], excluding title: String?) -> String? {
        let normalizedTitle = title?.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return lines
            .filter { line in
                let normalizedLine = line.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                return normalizedLine != normalizedTitle && line.isLikelyCreatorCredit
            }
            .first
            .map { line in
                line.replacingOccurrences(of: #"^(by|par|de|d[’'])\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
            }
            .map(normalizedCoverText)
            .flatMap(\ .nilIfBlank)
    }

    private func extractYear(from text: String) -> String? {
        guard let range = text.range(of: #"\b(19|20)\d{2}\b"#, options: .regularExpression) else { return nil }
        return String(text[range])
    }

    private func normalizedCoverText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:()[]{}\"“”"))
    }
}

@Generable(description: "Metadata extracted from a photographed cultural work cover", representNilExplicitlyInGeneratedContent: true)
private struct GeneratedEchoCoverScan {
    @Guide(description: "Main visible work title only. Nil if unclear.")
    var title: String?

    @Guide(description: "Visible or extremely certain creator name. Nil if unclear.")
    var creator: String?

    @Guide(description: "Explicit visible four-digit year only. Nil if absent or uncertain.")
    var year: String?

    @Guide(description: "Best visible category for the work")
    var category: GeneratedCoverCategory

    @Guide(description: "Short transcription of useful visible text from the cover")
    var visibleText: String

    @Guide(description: "High only when the title is clearly visible and metadata is strongly supported")
    var confidence: GeneratedCoverConfidence

    func makeResult(source: EchoCoverScanSource) -> EchoCoverScanResult {
        EchoCoverScanResult(
            title: confidence.echoConfidence.allowsSpecificFacts ? title.cleanGeneratedOptionalField : title.cleanGeneratedOptionalField,
            creator: confidence.echoConfidence.allowsSpecificFacts ? creator.cleanGeneratedOptionalField : nil,
            year: confidence.echoConfidence.allowsSpecificFacts ? year.validCoverYear : nil,
            category: category.echoCategory,
            confidence: confidence.echoConfidence,
            visibleText: visibleText.cleanGeneratedRequiredField(fallback: ""),
            source: source
        )
    }
}

@Generable(description: "Allowed Echo cover categories")
private enum GeneratedCoverCategory {
    case film
    case book
    case music
    case painting
    case videoGame
    case performance
    case place
    case object
    case other

    var echoCategory: EchoCategory {
        switch self {
        case .film: .film
        case .book: .book
        case .music: .music
        case .painting: .painting
        case .videoGame: .videoGame
        case .performance: .performance
        case .place: .place
        case .object: .object
        case .other: .other
        }
    }
}

@Generable(description: "Cover scan confidence")
private enum GeneratedCoverConfidence {
    case high
    case medium
    case low

    var echoConfidence: EchoCoverScanConfidence {
        switch self {
        case .high: .high
        case .medium: .medium
        case .low: .low
        }
    }
}

private enum EchoCoverScanError: Error {
    case appleIntelligenceUnavailable
    case invalidImage
    case noRecognizedText
}

private extension Optional where Wrapped == String {
    var cleanGeneratedOptionalField: String? {
        switch self {
        case .some(let value): value.cleanGeneratedOptionalField
        case .none: nil
        }
    }

    var validCoverYear: String? {
        guard let value = cleanGeneratedOptionalField else { return nil }
        guard value.range(of: #"^(19|20)\d{2}$"#, options: .regularExpression) != nil else { return nil }
        return value
    }
}

private extension String {
    var cleanGeneratedOptionalField: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let emptyMarkers = ["unknown", "uncertain", "unspecified", "notmentioned", "none", "nil", "null", "n/a", "na", "-"]
        guard !emptyMarkers.contains(normalized) else { return nil }
        return trimmed
    }

    func cleanGeneratedRequiredField(fallback: String) -> String {
        cleanGeneratedOptionalField ?? fallback
    }

    var coverTitleScore: Int {
        let letters = filter { $0.isLetter }.count
        let words = split(separator: " ").count
        let uppercasedLetters = filter { $0.isLetter && $0.isUppercase }.count
        let uppercaseBonus = uppercasedLetters > letters / 2 ? 12 : 0
        return letters + min(words, 6) * 4 + uppercaseBonus
    }

    var isLikelyCreatorCredit: Bool {
        let normalized = folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()
        return normalized.hasPrefix("by ")
            || normalized.hasPrefix("par ")
            || normalized.hasPrefix("de ")
            || normalized.hasPrefix("d'")
            || normalized.hasPrefix("d’")
            || split(separator: " ").count == 2 && !contains { $0.isNumber }
    }
}
