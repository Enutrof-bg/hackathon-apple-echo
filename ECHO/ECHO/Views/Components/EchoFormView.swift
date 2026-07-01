import SwiftUI

struct EchoFormView: View {
    @Binding var title: String
    @Binding var creator: String
    @Binding var category: EchoCategory
    @Binding var emotion: EchoEmotion
    @Binding var memoryText: String
    @Binding var echoLine: String
    @Binding var year: String
    @Binding var discoveryStatus: EchoDiscoveryStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Specimen")

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            TextField("Creator", text: $creator)
                .textFieldStyle(.roundedBorder)

            TextField("Year", text: $year)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Picker("Category", selection: $category) {
                    ForEach(EchoCategory.allCases) { category in
                        Text(category.title).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                Picker("Emotion", selection: $emotion) {
                    ForEach(EchoEmotion.allCases) { emotion in
                        Text(emotion.title).tag(emotion)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .echoGlassPanel(tint: EchoStyle.accent.opacity(0.08))

            Picker("Status", selection: $discoveryStatus) {
                ForEach(EchoDiscoveryStatus.allCases) { status in
                    Label(status.title, systemImage: status.symbolName).tag(status)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Memory")

                TextEditor(text: $memoryText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(8)
                    .echoGlassPanel(tint: EchoStyle.accent.opacity(0.06))
            }

            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Summary")

                TextField("Summary", text: $echoLine, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
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
