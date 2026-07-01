import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            GalleryView()
                .tabItem {
                    Label("Gallery", systemImage: "square.grid.2x2")
                }

            HomeView()
                .tabItem {
                    Label("Capture", systemImage: "mic")
                }

            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "safari")
                }
        }
        .tint(EchoStyle.ink)
    }
}

enum EchoStyle {
    static let background = Color(red: 0.982, green: 0.978, blue: 0.958)
    static let surface = Color(red: 0.995, green: 0.992, blue: 0.976)
    static let surfaceSecondary = Color(red: 0.928, green: 0.924, blue: 0.900)
    static let border = Color.black.opacity(0.72)
    static let ink = Color(red: 0.055, green: 0.055, blue: 0.052)
    static let mutedInk = Color.black.opacity(0.54)
    static let accent = ink
    static let accentMuted = Color.black.opacity(0.42)
    static let graphite = ink
    static let amber = Color(red: 0.620, green: 0.420, blue: 0.160)

    static func emotionColor(_ emotion: EchoEmotion) -> Color {
        switch emotion {
        case .nostalgia: Color(red: 0.650, green: 0.255, blue: 0.040)
        case .joy: Color(red: 0.965, green: 0.805, blue: 0.000)
        case .wonder: Color(red: 0.000, green: 0.290, blue: 0.760)
        case .melancholy: Color(red: 0.000, green: 0.585, blue: 0.790)
        case .calm: Color(red: 0.000, green: 0.545, blue: 0.245)
        case .shock: Color(red: 0.920, green: 0.120, blue: 0.040)
        case .love: Color(red: 0.820, green: 0.000, blue: 0.410)
        case .curiosity: Color(red: 0.500, green: 0.150, blue: 0.760)
        }
    }

    static func cardBorder(_ color: Color = border) -> some ShapeStyle {
        color
    }
}

extension View {
    @ViewBuilder
    func echoGlassPanel(tint: Color = EchoStyle.ink.opacity(0.08)) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular.tint(tint), in: .rect(cornerRadius: 8))
        } else {
            self
                .background(EchoStyle.surface.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(EchoStyle.border.opacity(0.22), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    func echoGlassButtonStyle(prominent: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else if prominent {
            self.buttonStyle(.borderedProminent)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    func echoSectionTitle() -> some View {
        self
            .font(.caption)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .tracking(1.1)
            .foregroundStyle(EchoStyle.ink)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [EchoMemory.self, EchoMemoryStoredLink.self], inMemory: true)
}
