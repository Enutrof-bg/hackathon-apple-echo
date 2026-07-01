import SwiftUI

struct DateStampView: View {
    let date: Date
    let emotion: EchoEmotion
    var compact: Bool = false
    var rotationDegrees: Double = 0

    private var stampColor: Color {
        EchoStyle.emotionColor(emotion)
    }

    private var dateParts: DateParts {
        Self.makeDateParts(from: date)
    }

    private var inkPressure: InkPressure {
        Self.makeInkPressure(date: date, emotion: emotion)
    }

    var body: some View {
        ZStack {
            stampLine
                .blur(radius: compact ? 0.18 : 0.24)
                .opacity(0.34)
                .offset(x: inkPressure.ghostOffset.width, y: inkPressure.ghostOffset.height)
                .mask(inkPressureMask)

            stampLine
                .opacity(0.92)
                .mask(inkPressureMask)
                .mask(inkWearMask)

            stampLine
                .opacity(inkPressure.secondPassOpacity)
                .offset(x: -inkPressure.ghostOffset.width * 0.7, y: inkPressure.ghostOffset.height * 0.5)
                .mask(inkWearMask)
        }
        .foregroundStyle(stampColor)
        .rotationEffect(.degrees(rotationDegrees))
        .blendMode(.multiply)
        .compositingGroup()
        .opacity(0.96)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Carte debloquee le \(Self.accessibilityFormatter.string(from: date)), emotion \(emotion.title.lowercased()).")
        .allowsHitTesting(false)
    }

    private var stampLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: compact ? 8 : 13) {
            HStack(spacing: compact ? 2 : 4) {
                ForEach(dateParts.dayDigits.indices, id: \.self) { index in
                    stampText(String(dateParts.dayDigits[index]))
                }
            }

            stampText(dateParts.month)
            stampText(dateParts.year)
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    private func stampText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: compact ? 24 : 42, weight: .heavy, design: .rounded))
            .textCase(.uppercase)
            .tracking(compact ? 0.2 : 0.6)
            .scaleEffect(x: 0.64, y: 1.08, anchor: .center)
    }

    private var inkPressureMask: some View {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(inkPressure.leadingOpacity), location: 0),
                .init(color: .white.opacity(inkPressure.centerOpacity), location: 0.46),
                .init(color: .white.opacity(inkPressure.trailingOpacity), location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var inkWearMask: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(.white.opacity(0.82))

                ForEach(Self.wornBands.indices, id: \.self) { index in
                    let band = Self.wornBands[index]
                    Rectangle()
                        .fill(.white.opacity(band.opacity))
                        .frame(height: compact ? band.height * 0.7 : band.height)
                        .rotationEffect(.degrees(band.rotation))
                        .position(
                            x: geometry.size.width * band.x,
                            y: geometry.size.height * band.y
                        )
                }

                ForEach(Self.speckles.indices, id: \.self) { index in
                    let speckle = Self.speckles[index]
                    Capsule()
                        .fill(.white.opacity(speckle.opacity))
                        .frame(
                            width: compact ? speckle.size.width * 0.62 : speckle.size.width,
                            height: compact ? speckle.size.height * 0.62 : speckle.size.height
                        )
                        .position(
                            x: geometry.size.width * speckle.x,
                            y: geometry.size.height * speckle.y
                        )
                }
            }
        }
    }

    private static func makeDateParts(from date: Date) -> DateParts {
        let calendar = Calendar.current
        let day = String(format: "%02d", calendar.component(.day, from: date))
        let year = String(calendar.component(.year, from: date))
        let month = monthFormatter.string(from: date).uppercased()
        return DateParts(dayDigits: Array(day), month: month, year: year)
    }

    private static func makeInkPressure(date: Date, emotion: EchoEmotion) -> InkPressure {
        let calendar = Calendar.current
        let seed = calendar.component(.day, from: date)
            + calendar.component(.month, from: date) * 7
            + calendar.component(.year, from: date)
            + emotion.rawValue.unicodeScalars.reduce(0) { $0 + Int($1.value) }

        let weakSide = seed % 3
        let leading = weakSide == 0 ? 0.48 : Double(74 + (seed % 18)) / 100
        let trailing = weakSide == 1 ? 0.46 : Double(72 + ((seed / 3) % 20)) / 100
        let center = weakSide == 2 ? 0.58 : Double(84 + ((seed / 5) % 14)) / 100
        let secondPass = Double(12 + ((seed / 11) % 24)) / 100

        return InkPressure(
            leadingOpacity: leading,
            centerOpacity: center,
            trailingOpacity: trailing,
            secondPassOpacity: secondPass,
            ghostOffset: CGSize(
                width: CGFloat(((seed / 13) % 5) - 2) * 0.65,
                height: CGFloat(((seed / 17) % 5) - 2) * 0.45
            )
        )
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"
        return formatter
    }()

    private static let accessibilityFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    private static let wornBands: [InkBand] = [
        InkBand(x: 0.18, y: 0.28, height: 3, rotation: -1.5, opacity: 0.06),
        InkBand(x: 0.52, y: 0.56, height: 4, rotation: 1.2, opacity: 0.08),
        InkBand(x: 0.78, y: 0.74, height: 3, rotation: -0.8, opacity: 0.05)
    ]

    private static let speckles: [InkSpeckle] = [
        InkSpeckle(x: 0.08, y: 0.30, size: CGSize(width: 6, height: 2), opacity: 0.16),
        InkSpeckle(x: 0.14, y: 0.70, size: CGSize(width: 9, height: 2), opacity: 0.12),
        InkSpeckle(x: 0.26, y: 0.18, size: CGSize(width: 4, height: 2), opacity: 0.14),
        InkSpeckle(x: 0.38, y: 0.62, size: CGSize(width: 10, height: 2), opacity: 0.10),
        InkSpeckle(x: 0.51, y: 0.34, size: CGSize(width: 6, height: 2), opacity: 0.13),
        InkSpeckle(x: 0.64, y: 0.80, size: CGSize(width: 11, height: 2), opacity: 0.10),
        InkSpeckle(x: 0.76, y: 0.24, size: CGSize(width: 5, height: 2), opacity: 0.12),
        InkSpeckle(x: 0.88, y: 0.56, size: CGSize(width: 8, height: 2), opacity: 0.10),
        InkSpeckle(x: 0.94, y: 0.40, size: CGSize(width: 4, height: 2), opacity: 0.11),
        InkSpeckle(x: 0.58, y: 0.12, size: CGSize(width: 7, height: 2), opacity: 0.09)
    ]
}

private struct DateParts {
    let dayDigits: [Character]
    let month: String
    let year: String
}

private struct InkPressure {
    let leadingOpacity: Double
    let centerOpacity: Double
    let trailingOpacity: Double
    let secondPassOpacity: Double
    let ghostOffset: CGSize
}

private struct InkBand {
    let x: CGFloat
    let y: CGFloat
    let height: CGFloat
    let rotation: Double
    let opacity: Double
}

private struct InkSpeckle {
    let x: CGFloat
    let y: CGFloat
    let size: CGSize
    let opacity: Double
}

#Preview {
    VStack(spacing: 30) {
        DateStampView(date: Date(), emotion: .nostalgia)
        DateStampView(date: Date(), emotion: .wonder, compact: true, rotationDegrees: -3)
    }
    .padding()
    .background(EchoStyle.surface)
}
