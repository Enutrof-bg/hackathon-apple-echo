import SwiftUI

struct DiscoverFilterView: View {
    @State private var comfortLevel = 0.48
    @State private var emotionalIntensity = 0.62
    @State private var categoryFocus = 0.54
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
                    previewSection
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
            .accessibilityHint("Choose the emotion used to tune discovery recommendations.")

            filterSlider(
                title: "Emotional intensity",
                value: $emotionalIntensity,
                leftLabel: "Subtle",
                rightLabel: "Strong"
            )
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
            .accessibilityHint("Choose the cultural category used to tune discovery recommendations.")

            filterSlider(
                title: "Category focus",
                value: $categoryFocus,
                leftLabel: "Mixed",
                rightLabel: "Focused"
            )
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

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current Direction")
                .echoSectionTitle()

            HStack(spacing: 8) {
                Circle()
                    .fill(EchoStyle.emotionColor(selectedEmotion))
                    .frame(width: 9, height: 9)

                Text("\(selectedEmotion.title) / \(selectedCategory.title)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Spacer()

                Text(comfortLevel < 0.5 ? "Comfort" : "Surprise")
                    .font(.caption)
                    .foregroundStyle(EchoStyle.mutedInk)
            }
            .padding(.vertical, 12)
            .overlay(alignment: .top) { rule(opacity: 0.5) }
            .overlay(alignment: .bottom) { rule(opacity: 0.5) }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Current recommendation direction")
            .accessibilityValue("\(selectedEmotion.title), \(selectedCategory.title), \(comfortLevel < 0.5 ? "comfort" : "surprise")")
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
                .accessibilityLabel(title)
                .accessibilityValue("\(Int(value.wrappedValue * 100)) percent")
                .accessibilityHint("Adjust between \(leftLabel.lowercased()) and \(rightLabel.lowercased()).")

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
