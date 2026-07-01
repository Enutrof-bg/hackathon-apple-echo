import SwiftUI
#if os(iOS)
import AudioToolbox
import UIKit
#endif

struct EchoCardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let content: any EchoCardPresentable

    @State private var stampScale: CGFloat = 1
    @State private var stampOpacity: Double = 1
    @State private var inkSpread = false

    init(memory: some EchoCardPresentable) {
        self.content = memory
    }

    private var isOpenCard: Bool {
        content.discoveryStatus == .notDiscovered
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            cardContent

            if let unlockedAt = content.unlockedAt {
                stampOverlay(date: unlockedAt)
                    .padding(.trailing, 8)
                    .padding(.bottom, 28)
                    .offset(stableStampOffset)
                    .transition(.scale(scale: 1.22).combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Opens the Echo detail.")
        .animation(.spring(response: 0.24, dampingFraction: 0.62), value: content.unlockedAt != nil)
        .onChange(of: content.unlockedAt) { oldValue, newValue in
            if oldValue == nil, newValue != nil {
                playStampImpact()
            } else if oldValue != nil, newValue == nil {
                playStampRemoval()
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader

            if isOpenCard {
                openBadge
                    .padding(.top, 10)
            }

            Spacer(minLength: 12)

            VStack(alignment: .leading, spacing: 6) {
                Text(content.title)
                    .font(.system(.title3, design: .default))
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .foregroundStyle(isOpenCard ? EchoStyle.mutedInk : EchoStyle.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.72)

                if let creator = content.creator, !creator.isEmpty {
                    Text(creator)
                        .font(.caption)
                        .foregroundStyle(EchoStyle.mutedInk)
                        .lineLimit(2)
                }
            }


            Spacer(minLength: 12)

            cardFooter
        }
        .padding(14)
        .aspectRatio(1, contentMode: .fit)
        .background(isOpenCard ? EchoStyle.surfaceSecondary.opacity(0.55) : EchoStyle.surface)
        .overlay(cardBorder)
    }

    private func stampOverlay(date: Date) -> some View {
        ZStack {
            if inkSpread {
                DateStampView(
                    date: date,
                    emotion: content.emotion,
                    compact: true,
                    rotationDegrees: stableStampRotation
                )
                .scaleEffect(1.08)
                .opacity(0.18)
                .blur(radius: 1.4)
            }

            DateStampView(
                date: date,
                emotion: content.emotion,
                compact: true,
                rotationDegrees: stableStampRotation
            )
            .scaleEffect(stampScale)
            .opacity(stampOpacity)
        }
        .accessibilityHidden(false)
    }

    private var cardHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Label(content.category.title, systemImage: content.category.symbolName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(isOpenCard ? EchoStyle.mutedInk : EchoStyle.ink)
                    .labelStyle(.titleAndIcon)

                Rectangle()
                    .fill(EchoStyle.border.opacity(isOpenCard ? 0.34 : 0.72))
                    .frame(width: 30, height: 1)
            }

            Spacer()

            Image(systemName: isOpenCard ? "clock" : "bookmark")
                .font(.caption)
                .foregroundStyle(isOpenCard ? EchoStyle.mutedInk : EchoStyle.ink)
        }
    }

    private var openBadge: some View {
        Label(content.discoveryStatus.badgeTitle, systemImage: content.discoveryStatus.symbolName)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(EchoStyle.mutedInk)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    @ViewBuilder
    private var cardBorder: some View {
        if isOpenCard {
            Rectangle()
                .stroke(EchoStyle.border.opacity(0.34), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        } else {
            Rectangle()
                .stroke(EchoStyle.border, lineWidth: 1)
        }
    }

    private var cardFooter: some View {
        HStack(alignment: .center, spacing: 7) {
            Circle()
                .fill(isOpenCard ? EchoStyle.mutedInk.opacity(0.35) : emotionColor)
                .frame(width: 7, height: 7)

            Text(isOpenCard ? "Open" : content.emotion.title)
                .font(.caption2)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(isOpenCard ? EchoStyle.mutedInk : EchoStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 8)

            if let year = content.year, !year.isEmpty {
                Text(year)
                    .font(.caption2)
                    .foregroundStyle(EchoStyle.mutedInk)
            }
        }
    }

    private var emotionColor: Color {
        EchoStyle.emotionColor(content.emotion)
    }

    private var accessibilityLabel: String {
        var parts = [content.title, content.category.title, content.discoveryStatus.badgeTitle]
        if let creator = content.creator, !creator.isEmpty {
            parts.insert(creator, at: 1)
        }
        return parts.joined(separator: ", ")
    }

    private var accessibilityValue: String {
        let year = content.year?.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts = [content.emotion.title]
        if let year, !year.isEmpty {
            parts.append(year)
        }
        return parts.joined(separator: ". ")
    }

    private var stableStampRotation: Double {
        Double((stableStampSeed % 9) - 4)
    }

    private var stableStampOffset: CGSize {
        CGSize(
            width: CGFloat((stableStampSeed % 21) - 10),
            height: CGFloat(((stableStampSeed / 3) % 17) - 8)
        )
    }

    private var stableStampSeed: Int {
        content.id.uuidString.unicodeScalars.reduce(0) { partialResult, scalar in
            partialResult + Int(scalar.value)
        }
    }

    private func playStampImpact() {
        guard !reduceMotion else {
            stampScale = 1
            stampOpacity = 0.85
            inkSpread = false
            return
        }

        stampScale = 1.8
        stampOpacity = 0
        inkSpread = false

        withAnimation(.easeIn(duration: 0.10)) {
            stampScale = 0.92
            stampOpacity = 0.9
            inkSpread = true
        }

#if os(iOS)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.72)
        AudioServicesPlaySystemSound(1104)
#endif

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(110))
            withAnimation(.spring(response: 0.22, dampingFraction: 0.62)) {
                stampScale = 1
                stampOpacity = 1
            }

            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.easeOut(duration: 0.18)) {
                inkSpread = false
            }
        }
    }

    private func playStampRemoval() {
        guard !reduceMotion else { return }

        withAnimation(.easeOut(duration: 0.12)) {
            stampScale = 0.84
            stampOpacity = 0
        }

#if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.42)
        AudioServicesPlaySystemSound(1157)
#endif

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(160))
            stampScale = 1
            stampOpacity = 1
        }
    }
}

#Preview {
    EchoCardView(
        memory: EchoMemoryDraft(
            title: "The Lord of the Rings",
            creator: "J.R.R. Tolkien",
            category: .film,
            emotion: .nostalgia,
            memory: "I watched it every winter with my brother.",
            unlockedAt: Date()
        )
    )
    .padding()
    .background(EchoStyle.background)
}
