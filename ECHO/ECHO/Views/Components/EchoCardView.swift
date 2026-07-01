import SwiftUI

struct EchoCardView: View {
    private let content: any EchoCardPresentable

    init(memory: some EchoCardPresentable) {
        self.content = memory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(content.category.title, systemImage: content.category.symbolName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(accentColor)

                if content.discoveryStatus == .notDiscovered {
                    Label(content.discoveryStatus.badgeTitle, systemImage: content.discoveryStatus.symbolName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                }

                Spacer()

                Text(content.emotion.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(content.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let creator = content.creator, !creator.isEmpty {
                    Text(creator)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Text(content.echoLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(cardBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var cardBackgroundColor: Color {
        content.discoveryStatus == .notDiscovered ? Color(.secondarySystemGroupedBackground) : .white
    }

    private var borderColor: Color {
        content.discoveryStatus == .notDiscovered ? Color.secondary.opacity(0.22) : accentColor.opacity(0.25)
    }

    private var accentColor: Color {
        if content.discoveryStatus == .notDiscovered {
            return .secondary
        }

        switch content.emotion {
        case .nostalgia:
            return .indigo
        case .joy:
            return .yellow
        case .wonder:
            return .purple
        case .melancholy:
            return .blue
        case .calm:
            return .teal
        case .shock:
            return .red
        case .love:
            return .pink
        case .curiosity:
            return .green
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
            echoLine: "A winter ritual that made courage feel close again."
        )
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
