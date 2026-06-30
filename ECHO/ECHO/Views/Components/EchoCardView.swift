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
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(accentColor.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var accentColor: Color {
        switch content.emotion {
        case .nostalgia: .indigo
        case .joy: .yellow
        case .wonder: .purple
        case .melancholy: .blue
        case .calm: .teal
        case .shock: .red
        case .love: .pink
        case .curiosity: .green
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
