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
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            TextField("Creator", text: $creator)
                .textFieldStyle(.roundedBorder)

            TextField("Year", text: $year)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)

            Picker("Category", selection: $category) {
                ForEach(EchoCategory.allCases) { category in
                    Text(category.title).tag(category)
                }
            }
            .pickerStyle(.menu)

            Picker("Emotion", selection: $emotion) {
                ForEach(EchoEmotion.allCases) { emotion in
                    Text(emotion.title).tag(emotion)
                }
            }
            .pickerStyle(.menu)

            Picker("Status", selection: $discoveryStatus) {
                ForEach(EchoDiscoveryStatus.allCases) { status in
                    Label(status.title, systemImage: status.symbolName).tag(status)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Text("Memory")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextEditor(text: $memoryText)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Echo")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("Echo line", text: $echoLine, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
