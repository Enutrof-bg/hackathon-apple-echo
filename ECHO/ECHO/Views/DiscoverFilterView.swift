import SwiftUI

struct DiscoverFilterView: View {
    @State private var comfortLevel = 0.48
    @State private var selectedEmotion: EchoEmotion = .wonder
    @State private var selectedCategory: EchoCategory = .film

    var body: some View {
        ZStack {
            EchoStyle.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    emotionSection
                    categorySection
                    discoverySection
                }
                .padding(20)
            }
        }
        .navigationTitle("Filters")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommendation Tuning")
                .font(.title2)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(0.4)

            Rectangle()
                .fill(EchoStyle.border)
                .frame(height: 1)

            Text("Prototype controls for shaping future Discover recommendations.")
                .font(.caption)
                .foregroundStyle(EchoStyle.mutedInk)
        }
    }

    private var emotionSection: some View {
        filterSection(title: "Emotion") {
            Picker("Primary emotion", selection: $selectedEmotion) {
                ForEach(EchoEmotion.allCases) { emotion in
                    HStack {
                        Circle()
                            .fill(EchoStyle.emotionColor(emotion))
                            .frame(width: 8, height: 8)
                        Text(emotion.title)
                    }
                    .tag(emotion)
                }
            }
            .pickerStyle(.menu)
            .tint(EchoStyle.ink)
        }
    }

    private var categorySection: some View {
        filterSection(title: "Category") {
            Picker("Cultural category", selection: $selectedCategory) {
                ForEach(EchoCategory.allCases) { category in
                    Text(category.title).tag(category)
                }
            }
            .pickerStyle(.menu)
            .tint(EchoStyle.ink)
        }
    }

    private var discoverySection: some View {
        filterSection(title: "Discovery Range") {
            filterSlider(
                title: "Comfort / surprise",
                value: $comfortLevel,
                leftLabel: "Comfort",
                rightLabel: "Surprise"
            )
        }
    }

    private func filterSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .echoSectionTitle()

            content()
        }
    }

    private func filterSlider(title: String, value: Binding<Double>, leftLabel: String, rightLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                Text("\(Int(value.wrappedValue * 100))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(EchoStyle.mutedInk)
            }

            Slider(value: value, in: 0...1)
                .tint(EchoStyle.ink)

            HStack {
                Text(leftLabel)
                Spacer()
                Text(rightLabel)
            }
            .font(.caption2)
            .textCase(.uppercase)
            .foregroundStyle(EchoStyle.mutedInk)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) { rule(opacity: 0.34) }
    }

    private func rule(opacity: Double = 0.72) -> some View {
        Rectangle()
            .fill(EchoStyle.border.opacity(opacity))
            .frame(height: 1)
    }
}

#Preview {
    NavigationStack {
        DiscoverFilterView()
    }
}
