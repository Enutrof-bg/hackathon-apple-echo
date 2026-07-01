import Foundation
import SwiftData

@Model
final class EchoMemory {
    var id: UUID
    var title: String
    var creator: String?
    var category: EchoCategory
    var emotion: EchoEmotion
    var memory: String
    var year: String?
    var originalTranscript: String?
    var audioFileName: String?
    var audioDuration: TimeInterval?
    var discoveryStatusRawValue: String?
    var unlockedAt: Date?
    var createdAt: Date
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        creator: String? = nil,
        category: EchoCategory,
        emotion: EchoEmotion,
        memory: String,
        year: String? = nil,
        originalTranscript: String? = nil,
        audioFileName: String? = nil,
        audioDuration: TimeInterval? = nil,
        discoveryStatus: EchoDiscoveryStatus = .discovered,
        unlockedAt: Date? = nil,
        createdAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.creator = creator
        self.category = category
        self.emotion = emotion
        self.memory = memory
        self.year = year
        self.originalTranscript = originalTranscript
        self.audioFileName = audioFileName
        self.audioDuration = audioDuration
        self.discoveryStatusRawValue = discoveryStatus.rawValue
        self.unlockedAt = unlockedAt ?? (discoveryStatus == .discovered ? createdAt : nil)
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }

    @Transient
    var discoveryStatus: EchoDiscoveryStatus {
        get {
            guard let rawValue = discoveryStatusRawValue,
                  let status = EchoDiscoveryStatus(rawValue: rawValue) else {
                return .discovered
            }
            return status
        }
        set {
            discoveryStatusRawValue = newValue.rawValue
        }
    }
}

enum EchoDiscoveryStatus: String, Codable, CaseIterable, Identifiable {
    case discovered
    case notDiscovered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .discovered: "Discovered"
        case .notDiscovered: "Not Discovered"
        }
    }

    var badgeTitle: String {
        switch self {
        case .discovered: "Discovered"
        case .notDiscovered: "Not discovered yet"
        }
    }

    var symbolName: String {
        switch self {
        case .discovered: "checkmark.circle"
        case .notDiscovered: "clock"
        }
    }
}

enum EchoCategory: String, Codable, CaseIterable, Identifiable {
    case film
    case book
    case music
    case painting
    case videoGame
    case performance
    case place
    case object
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .film: "Film"
        case .book: "Book"
        case .music: "Music"
        case .painting: "Painting"
        case .videoGame: "Video Game"
        case .performance: "Performance"
        case .place: "Place"
        case .object: "Object"
        case .other: "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .film: "film"
        case .book: "book.closed"
        case .music: "music.note"
        case .painting: "paintpalette"
        case .videoGame: "gamecontroller"
        case .performance: "theatermasks"
        case .place: "mappin.and.ellipse"
        case .object: "cube"
        case .other: "sparkle"
        }
    }
}

enum EchoEmotion: String, Codable, CaseIterable, Identifiable {
    case nostalgia
    case joy
    case wonder
    case melancholy
    case calm
    case shock
    case love
    case curiosity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nostalgia: "Nostalgia"
        case .joy: "Joy"
        case .wonder: "Wonder"
        case .melancholy: "Melancholy"
        case .calm: "Calm"
        case .shock: "Shock"
        case .love: "Love"
        case .curiosity: "Curiosity"
        }
    }
}
