import SwiftUI

/// Visual state for the central Echo capture button.
enum ScribbleEchoButtonState: Equatable {
    case idle
    case pressed
    case recording
}

struct ScribbleEchoButton: View {
    var state: ScribbleEchoButtonState = .idle
    var size: CGFloat = 180
    var onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false
    @State private var rippleTrigger = 0

    private var resolvedState: ScribbleEchoButtonState {
        isPressed ? .pressed : state
    }

    var body: some View {
        Button {
            playTap()
        } label: {
            ZStack {
                ScribbleGlassBacking(state: resolvedState)
                    .frame(width: size * 1.08, height: size * 1.08)

                ScribbleRipple(trigger: rippleTrigger)
                    .frame(width: size * 1.18, height: size * 1.18)

                ScribbleCanvas(
                    state: resolvedState,
                    reduceMotion: reduceMotion
                )
                .frame(width: size, height: size)
                .scaleEffect(resolvedState == .pressed ? 0.94 : 1)
                .rotationEffect(.degrees(rotation(for: resolvedState)))
                .animation(.spring(response: 0.28, dampingFraction: 0.68), value: resolvedState)
            }
            .frame(width: max(size * 1.28, 88), height: max(size * 1.28, 88))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Créer un souvenir")
        .accessibilityAddTraits(.isButton)
        .sensoryFeedback(.selection, trigger: rippleTrigger)
    }

    private func playTap() {
        rippleTrigger += 1

        guard !reduceMotion else {
            onTap()
            return
        }

        withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) {
            isPressed = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(110))
            withAnimation(.spring(response: 0.46, dampingFraction: 0.62)) {
                isPressed = false
            }
            onTap()
        }
    }

    private func rotation(for state: ScribbleEchoButtonState) -> Double {
        switch state {
        case .idle: 0
        case .pressed: -1.4
        case .recording: 1.8
        }
    }
}

struct ScribbleCanvas: View {
    var state: ScribbleEchoButtonState
    var reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas(rendersAsynchronously: true) { context, size in
                renderScribble(in: &context, size: size, time: reduceMotion ? 0 : time)
            }
        }
    }

    private func renderScribble(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let rect = CGRect(origin: .zero, size: size)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(size.width, size.height) * radiusMultiplier
        let lineCount = state == .recording ? 14 : 11

        for index in 0..<lineCount {
            let path = makeLinePath(
                index: index,
                center: center,
                radius: baseRadius,
                time: time,
                size: size
            )

            let pressure = strokeWidth(for: index, time: time)
            let opacity = strokeOpacity(for: index, time: time)
            let blur = index % 7 == 0 ? 0.34 : 0

            context.drawLayer { layer in
                if blur > 0 {
                    layer.addFilter(.blur(radius: blur))
                }

                layer.stroke(
                    path,
                    with: .color(ScribbleEchoPalette.ink.opacity(opacity)),
                    style: StrokeStyle(lineWidth: pressure, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }

    private var radiusMultiplier: CGFloat {
        switch state {
        case .idle: 0.34
        case .pressed: 0.29
        case .recording: 0.37
        }
    }

    private var motionAmplitude: CGFloat {
        switch state {
        case .idle: 4.0
        case .pressed: 8.0
        case .recording: 7.2
        }
    }

    private func makeLinePath(
        index: Int,
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        size: CGSize
    ) -> Path {
        let pointCount = 42
        let indexPhase = CGFloat(index) * 0.81
        let time = CGFloat(time)
        let contraction: CGFloat = state == .pressed ? 0.78 : 1.0
        let horizontalBias = 1.05 + CGFloat(index % 4) * 0.035
        let verticalBias = 0.90 + CGFloat((index + 2) % 4) * 0.045
        var points: [CGPoint] = []

        for pointIndex in 0..<pointCount {
            let progress = CGFloat(pointIndex) / CGFloat(pointCount - 1)
            let angle = progress * .pi * 2 * (1 + CGFloat(index % 3) * 0.035) + indexPhase
            let slowWave = sin(angle * 2.0 + time * 0.62 + indexPhase) * 0.22
            let counterWave = cos(angle * 3.6 - time * 0.47 + indexPhase * 0.7) * 0.14
            let tremor = sin(progress * .pi * 11 + time * (state == .recording ? 3.2 : 1.25) + indexPhase) * 0.07
            let memoryKnot = sin(angle * 5.1 + time * 0.28) * cos(progress * .pi * 4 + indexPhase) * 0.08
            let localRadius = radius * contraction * (0.82 + slowWave + counterWave + tremor + memoryKnot)
            let livingOffset = CGPoint(
                x: sin(time * 0.73 + indexPhase) * motionAmplitude,
                y: cos(time * 0.59 + indexPhase * 1.4) * motionAmplitude * 0.8
            )
            let point = CGPoint(
                x: center.x + cos(angle) * localRadius * horizontalBias + livingOffset.x,
                y: center.y + sin(angle) * localRadius * verticalBias + livingOffset.y
            )
            points.append(point)
        }

        return smoothedPath(points: points)
    }

    private func smoothedPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 2, let first = points.first else { return path }

        path.move(to: first)

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midpoint = CGPoint(
                x: (previous.x + current.x) * 0.5,
                y: (previous.y + current.y) * 0.5
            )
            path.addQuadCurve(to: midpoint, control: previous)
        }

        if let last = points.last {
            path.addLine(to: last)
        }

        return path
    }

    private func strokeWidth(for index: Int, time: TimeInterval) -> CGFloat {
        let base = 3.0 + CGFloat(index % 5) * 0.55
        let livingPressure = abs(sin(CGFloat(time) * 0.7 + CGFloat(index) * 1.33)) * 1.6
        let recordingBoost: CGFloat = state == .recording ? 1.0 : 0
        return base + livingPressure + recordingBoost
    }

    private func strokeOpacity(for index: Int, time: TimeInterval) -> Double {
        let base = 0.74 + Double(index % 4) * 0.045
        let flutter = abs(sin(time * 0.53 + Double(index) * 0.91)) * 0.10
        return min(0.95, base + flutter)
    }
}

private struct ScribbleGlassBacking: View {
    var state: ScribbleEchoButtonState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let pulse = reduceMotion ? 0 : sin(time * 2.0) * 0.5 + 0.5
            Circle()
                .fill(.ultraThinMaterial.opacity(state == .recording ? 0.18 : 0.10))
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.42), lineWidth: 1)
                )
                .shadow(color: ScribbleEchoPalette.sepia.opacity(state == .recording ? 0.24 : 0.14), radius: state == .recording ? 34 : 24, x: 0, y: 16)
                .scaleEffect(1 + CGFloat(pulse) * (state == .recording ? 0.055 : 0.025))
                .overlay(
                    Circle()
                        .stroke(ScribbleEchoPalette.sepia.opacity(state == .recording ? 0.16 : 0.08), lineWidth: 1.2)
                        .scaleEffect(1.08 + CGFloat(pulse) * 0.08)
                        .blur(radius: 6)
                )
        }
    }
}

private struct ScribbleRipple: View {
    var trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 0.2
    @State private var opacity: Double = 0
    @State private var previousTrigger = 0

    var body: some View {
        Circle()
            .stroke(ScribbleEchoPalette.ink.opacity(opacity), lineWidth: 1.2)
            .scaleEffect(scale)
            .onChange(of: trigger) { _, newValue in
                guard newValue != previousTrigger else { return }
                previousTrigger = newValue
                playRipple()
            }
    }

    private func playRipple() {
        guard !reduceMotion else { return }

        scale = 0.2
        opacity = 0.42
        withAnimation(.easeOut(duration: 0.64)) {
            scale = 1
            opacity = 0
        }
    }
}

private enum ScribbleEchoPalette {
    static let ink = Color(red: 0.018, green: 0.016, blue: 0.014)
    static let sepia = Color(red: 0.420, green: 0.290, blue: 0.170)
}

#Preview("Scribble Echo Button") {
    ZStack {
        EchoStyle.background.ignoresSafeArea()
        VStack(spacing: 30) {
            ScribbleEchoButton(state: .idle) {}
            ScribbleEchoButton(state: .pressed) {}
            ScribbleEchoButton(state: .recording) {}
        }
    }
}
