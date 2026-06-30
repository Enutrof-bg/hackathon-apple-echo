import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "waveform")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)

                Text("Bienvenue dans ECHO")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Une base simple pour commencer ton application iOS SwiftUI.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("ECHO")
        }
    }
}

#Preview {
    HomeView()
}
