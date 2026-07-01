import SwiftUI

struct EchoFormView: View {
    @Binding var title: String
    @Binding var creator: String
    @Binding var category: EchoCategory
    @Binding var emotion: EchoEmotion
    @Binding var memoryText: String
    @Binding var year: String
    @Binding var discoveryStatus: EchoDiscoveryStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Specimen")

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Title")
                .accessibilityHint("Enter the name of the work, book, film, album, or cultural object.")

            TextField("Creator", text: $creator)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Creator")
                .accessibilityHint("Enter the author, artist, director, or creator when known.")

            TextField("Year", text: $year)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Year")
                .accessibilityHint("Enter the release year when known.")

            HStack(spacing: 12) {
                Picker("Category", selection: $category) {
                    ForEach(EchoCategory.allCases) { category in
                        Text(category.title).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHint("Choose the type of cultural work.")

                Picker("Emotion", selection: $emotion) {
                    ForEach(EchoEmotion.allCases) { emotion in
                        Text(emotion.title).tag(emotion)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHint("Choose the emotion attached to this Echo.")
            }
            .padding(12)
            .echoGlassPanel(tint: EchoStyle.accent.opacity(0.08))

            Picker("Status", selection: $discoveryStatus) {
                ForEach(EchoDiscoveryStatus.allCases) { status in
                    Label(status.title, systemImage: status.symbolName).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityHint("Choose whether this work has already been discovered or is still waiting to be discovered.")

            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Memory")

                TextEditor(text: $memoryText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .accessibilityLabel("Memory")
                    .accessibilityHint("Write the personal memory, feeling, or context attached to this work.")
                    .padding(8)
                    .echoGlassPanel(tint: EchoStyle.accent.opacity(0.06))
            }

        }
        .padding(16)
        .echoGlassPanel(tint: EchoStyle.accent.opacity(0.08))
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(EchoStyle.accent)
    }
}
