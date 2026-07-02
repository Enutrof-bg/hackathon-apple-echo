import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

struct EchoWidgetMemorySnapshot: Equatable {
    let title: String
    let creator: String?
    let categoryTitle: String
    let categorySymbolName: String
    let emotionTitle: String
    let summary: String
    let discoveryStatus: EchoDiscoveryStatus
}

struct EchoOfTheDayEntry: TimelineEntry {
    let date: Date
    let memory: EchoWidgetMemorySnapshot?
}

struct EchoDiscoverNextEntry: TimelineEntry {
    let date: Date
    let memory: EchoWidgetMemorySnapshot?
    let reason: String?
}

struct EchoQuickCaptureEntry: TimelineEntry {
    let date: Date
}

struct EchoWidgetDataSource {
    func echoOfTheDay() -> EchoWidgetMemorySnapshot? {
        let memories = activeMemories()
            .filter { $0.discoveryStatus == .discovered }
            .sorted { first, second in
                if first.createdAt == second.createdAt {
                    return first.title < second.title
                }
                return first.createdAt > second.createdAt
            }

        guard let memory = memories.first else { return nil }
        return EchoWidgetMemorySnapshot(memory: memory)
    }

    func discoverNext() -> (memory: EchoWidgetMemorySnapshot?, reason: String?) {
        let memories = activeMemories()
        if let queuedMemory = EchoDiscoveryService().queueItems(from: memories).first {
            return (EchoWidgetMemorySnapshot(memory: queuedMemory), "Saved for later")
        }

        if let suggestion = EchoDiscoveryService().suggestions(existingMemories: memories).first {
            return (EchoWidgetMemorySnapshot(draft: suggestion.draft), suggestion.reason)
        }

        return (nil, nil)
    }

    private func activeMemories() -> [EchoMemory] {
        let context = EchoModelContainerProvider.makeContext()
        let descriptor = FetchDescriptor<EchoMemory>(
            sortBy: [SortDescriptor(\EchoMemory.createdAt, order: .reverse)]
        )

        return (try? context.fetch(descriptor).filter { $0.deletedAt == nil }) ?? []
    }
}

struct EchoOfTheDayProvider: TimelineProvider {
    func placeholder(in context: Context) -> EchoOfTheDayEntry {
        EchoOfTheDayEntry(date: Date(), memory: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (EchoOfTheDayEntry) -> Void) {
        completion(EchoOfTheDayEntry(date: Date(), memory: EchoWidgetDataSource().echoOfTheDay() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EchoOfTheDayEntry>) -> Void) {
        let entry = EchoOfTheDayEntry(date: Date(), memory: EchoWidgetDataSource().echoOfTheDay())
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date().addingTimeInterval(21_600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct EchoDiscoverNextProvider: TimelineProvider {
    func placeholder(in context: Context) -> EchoDiscoverNextEntry {
        EchoDiscoverNextEntry(date: Date(), memory: .discoverPlaceholder, reason: "A suggestion for your next discovery")
    }

    func getSnapshot(in context: Context, completion: @escaping (EchoDiscoverNextEntry) -> Void) {
        let data = EchoWidgetDataSource().discoverNext()
        completion(EchoDiscoverNextEntry(date: Date(), memory: data.memory ?? .discoverPlaceholder, reason: data.reason))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EchoDiscoverNextEntry>) -> Void) {
        let data = EchoWidgetDataSource().discoverNext()
        let entry = EchoDiscoverNextEntry(date: Date(), memory: data.memory, reason: data.reason)
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date().addingTimeInterval(21_600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct EchoQuickCaptureProvider: TimelineProvider {
    func placeholder(in context: Context) -> EchoQuickCaptureEntry {
        EchoQuickCaptureEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (EchoQuickCaptureEntry) -> Void) {
        completion(EchoQuickCaptureEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EchoQuickCaptureEntry>) -> Void) {
        completion(Timeline(entries: [EchoQuickCaptureEntry(date: Date())], policy: .never))
    }
}

struct EchoOfTheDayWidget: Widget {
    let kind = "EchoOfTheDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EchoOfTheDayProvider()) { entry in
            EchoOfTheDayWidgetView(entry: entry)
        }
        .configurationDisplayName("Echo of the Day")
        .description("Rediscover one saved Echo from your cultural journal.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct EchoDiscoverNextWidget: Widget {
    let kind = "EchoDiscoverNextWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EchoDiscoverNextProvider()) { entry in
            EchoDiscoverNextWidgetView(entry: entry)
        }
        .configurationDisplayName("Discover Next")
        .description("See a saved or curated work to discover next.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct EchoQuickCaptureWidget: Widget {
    let kind = "EchoQuickCaptureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EchoQuickCaptureProvider()) { entry in
            EchoQuickCaptureWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Capture")
        .description("Start a voice or regular Echo capture quickly.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct EchoOfTheDayWidgetView: View {
    let entry: EchoOfTheDayEntry

    var body: some View {
        EchoWidgetCard(title: "Echo of the Day", memory: entry.memory, emptyText: "Save an Echo to revisit it here.")
            .containerBackground(Color(.systemBackground), for: .widget)
    }
}

struct EchoDiscoverNextWidgetView: View {
    let entry: EchoDiscoverNextEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EchoWidgetHeader(title: "Discover Next", systemImage: "safari")

            if let memory = entry.memory {
                EchoWidgetMemoryContent(memory: memory)

                if let reason = entry.reason, !reason.isEmpty {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } else {
                Text("Your discovery queue is empty.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .containerBackground(Color(.systemBackground), for: .widget)
    }
}

struct EchoQuickCaptureWidgetView: View {
    let entry: EchoQuickCaptureEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EchoWidgetHeader(title: "Quick Capture", systemImage: "plus.bubble")

            VStack(spacing: 8) {
                Button(intent: OpenVoiceCaptureIntent()) {
                    Label("Voice", systemImage: "mic.circle")
                        .frame(maxWidth: .infinity)
                }

                if CaptureInputMode.cameraCaptureIsAvailable {
                    Button(intent: OpenCameraCaptureIntent()) {
                        Label("Scan", systemImage: "camera.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                }

                Button(intent: OpenCaptureIntent()) {
                    Label("Capture", systemImage: "waveform")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .padding(12)
        .containerBackground(Color(.systemBackground), for: .widget)
    }
}

struct EchoWidgetCard: View {
    let title: String
    let memory: EchoWidgetMemorySnapshot?
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EchoWidgetHeader(title: title, systemImage: "rectangle.stack")

            if let memory {
                EchoWidgetMemoryContent(memory: memory)
            } else {
                Text(emptyText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
    }
}

struct EchoWidgetHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
    }
}

struct EchoWidgetMemoryContent: View {
    let memory: EchoWidgetMemorySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(memory.categoryTitle, systemImage: memory.categorySymbolName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(memory.title)
                .font(.headline)
                .lineLimit(2)

            if let creator = memory.creator, !creator.isEmpty {
                Text(creator)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(memory.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }
}

extension EchoWidgetMemorySnapshot {
    init(memory: EchoMemory) {
        self.init(
            title: memory.title,
            creator: memory.creator,
            categoryTitle: memory.category.title,
            categorySymbolName: memory.category.symbolName,
            emotionTitle: memory.emotion.title,
            summary: memory.echoLine.trimmedFallback(memory.memory),
            discoveryStatus: memory.discoveryStatus
        )
    }

    init(draft: EchoMemoryDraft) {
        self.init(
            title: draft.title,
            creator: draft.creator,
            categoryTitle: draft.category.title,
            categorySymbolName: draft.category.symbolName,
            emotionTitle: draft.emotion.title,
            summary: draft.echoLine.trimmedFallback(draft.memory),
            discoveryStatus: draft.discoveryStatus
        )
    }

    static let placeholder = EchoWidgetMemorySnapshot(
        title: "La maison des mille feuilles",
        creator: "Mark Z. Danielewski",
        categoryTitle: "Book",
        categorySymbolName: "book.closed",
        emotionTitle: "Wonder",
        summary: "A memory about feeling lost inside a labyrinth of pages.",
        discoveryStatus: .discovered
    )

    static let discoverPlaceholder = EchoWidgetMemorySnapshot(
        title: "Invisible Cities",
        creator: "Italo Calvino",
        categoryTitle: "Book",
        categorySymbolName: "book.closed",
        emotionTitle: "Curiosity",
        summary: "A book to discover for imagined places, memory, and poetic fragments.",
        discoveryStatus: .notDiscovered
    )
}
