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
                ScribblePaperBacking(state: resolvedState)
                    .frame(width: size * 1.12, height: size * 1.12)

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
        let path = makeSingleScribblePath(center: center, radius: baseRadius, time: time)
        let pressure = state == .recording ? 1.72 : 1.52

        context.stroke(
            path,
            with: .color(ScribbleEchoPalette.ink.opacity(0.90)),
            style: StrokeStyle(lineWidth: pressure, lineCap: .round, lineJoin: .round)
        )
    }

    private var radiusMultiplier: CGFloat {
        switch state {
        case .idle: 0.42
        case .pressed: 0.34
        case .recording: 0.45
        }
    }

    private var motionAmplitude: CGFloat {
        switch state {
        case .idle: 2.6
        case .pressed: 4.8
        case .recording: 4.2
        }
    }

    private func makeLinePath(
        index: Int,
        pass: Int,
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        size: CGSize
    ) -> Path {
        let pointCount = 48
        let indexPhase = CGFloat(index) * 0.73 + CGFloat(pass) * 0.21
        let time = CGFloat(time)
        let contraction: CGFloat = state == .pressed ? 0.78 : 1.0
        let horizontalBias = 1.00 + CGFloat(index % 5) * 0.035
        let verticalBias = 0.88 + CGFloat((index + 2) % 5) * 0.04
        let loopTurns = 1.24 + CGFloat(index % 4) * 0.22
        let passJitter = CGFloat(pass) * 1.2
        var points: [CGPoint] = []

        for pointIndex in 0..<pointCount {
            let progress = CGFloat(pointIndex) / CGFloat(pointCount - 1)
            let angle = progress * .pi * 2 * loopTurns + indexPhase
            let slowWave = sin(angle * 1.7 + time * 1.18 + indexPhase) * 0.17
            let counterWave = cos(angle * 4.2 - time * 1.04 + indexPhase * 0.7) * 0.12
            let tremor = sin(progress * .pi * 19 + time * (state == .recording ? 9.0 : 5.6) + indexPhase) * 0.08
            let scratch = sin(progress * .pi * CGFloat(7 + index % 6) + time * 4.2 + CGFloat(pass)) * 0.045
            let centerDive = abs(sin(progress * .pi * CGFloat(3 + index % 3) + indexPhase + time * 0.34))
            let centerPull: CGFloat = index % 3 == 0 ? 0.42 : 0.18
            let protrusion = max(0, sin(progress * .pi * 5 + indexPhase)) * (index % 5 == 0 ? 0.28 : 0.08)
            let angularSpike = pointIndex % (7 + index % 4) == 0 ? CGFloat(0.16 + Double(index % 3) * 0.04) : 0
            let outerFill = abs(sin(progress * .pi * CGFloat(2 + index % 4) + indexPhase)) * 0.18
            let localRadius = radius * contraction * (0.58 + outerFill + slowWave + counterWave + tremor + scratch + protrusion - centerDive * centerPull)
            let livingOffset = CGPoint(
                x: sin(time * 3.6 + indexPhase) * motionAmplitude + cos(time * 8.8 + progress * 8 + indexPhase) * 1.0,
                y: cos(time * 3.1 + indexPhase * 1.4) * motionAmplitude * 0.85 + sin(time * 7.4 + progress * 9) * 0.9
            )
            let handOffset = CGPoint(
                x: sin(CGFloat(pointIndex * (index + 3)) * 0.47 + indexPhase) * (1.5 + passJitter),
                y: cos(CGFloat(pointIndex * (index + 5)) * 0.39 + indexPhase) * (1.4 + passJitter)
            )
            let point = CGPoint(
                x: center.x + cos(angle) * localRadius * (horizontalBias + angularSpike) + livingOffset.x + handOffset.x,
                y: center.y + sin(angle) * localRadius * (verticalBias + angularSpike * 0.7) + livingOffset.y + handOffset.y
            )
            points.append(point)
        }

        return hybridPath(points: points, angularSeed: index + pass * 3)
    }

    private func makeSingleScribblePath(
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval
    ) -> Path {
        let pointCount = state == .recording ? 620 : 520
        let time = CGFloat(time)
        let contraction: CGFloat = state == .pressed ? 0.82 : 1.0
        var points: [CGPoint] = []

        for pointIndex in 0..<pointCount {
            let progress = CGFloat(pointIndex) / CGFloat(pointCount - 1)
            let t = progress * .pi * 2
            let drift = time * 0.42
            let centerBias = 0.58 + 0.24 * sin(t * 9.0 + drift) + 0.18 * cos(t * 17.0 - drift * 0.7)
            let outerPulse = pow(max(0, sin(t * 6.0 + sin(t * 11.0) * 1.8)), 5.0)
            let centerPulse = pow(abs(cos(t * 14.0 + drift * 0.8)), 2.4)
            let densityScale = max(0.16, min(1.02, centerBias - centerPulse * 0.26 + outerPulse * 0.46))

            let rawX = sin(t * 13.0 + sin(t * 5.0) * 1.6 + drift)
                + 0.72 * sin(t * 29.0 - drift * 0.8)
                + 0.38 * cos(t * 47.0 + CGFloat(pointIndex % 13) * 0.21)
            let rawY = cos(t * 11.0 + cos(t * 7.0) * 1.9 - drift * 0.6)
                + 0.66 * sin(t * 31.0 + drift * 0.7)
                + 0.42 * cos(t * 41.0 - CGFloat(pointIndex % 17) * 0.18)

            let chaosX = tanh(rawX * 0.78) * densityScale
            let chaosY = tanh(rawY * 0.78) * densityScale
            let angularKick = pointIndex % 37 == 0 ? CGFloat(0.13) : 0

            let tremor = CGPoint(
                x: sin(time * 0.86 + progress * .pi * 43.0) * motionAmplitude,
                y: cos(time * 0.74 + progress * .pi * 39.0) * motionAmplitude * 0.82
            )
            let handJitter = CGPoint(
                x: sin(CGFloat(pointIndex) * 1.73 + time * 0.52) * 0.72,
                y: cos(CGFloat(pointIndex) * 1.41 - time * 0.48) * 0.66
            )

            let point = CGPoint(
                x: center.x + chaosX * radius * contraction * (1.0 + angularKick) + tremor.x + handJitter.x,
                y: center.y + chaosY * radius * contraction * (0.96 + angularKick * 0.6) + tremor.y + handJitter.y
            )
            points.append(point)
        }

        return hybridPath(points: points, angularSeed: 7)
    }

    private func makeCoreLinePath(
        index: Int,
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval
    ) -> Path {
        let pointCount = 36
        let time = CGFloat(time)
        let phase = CGFloat(index) * 1.17
        let contraction: CGFloat = state == .pressed ? 0.72 : 1.0
        var points: [CGPoint] = []

        for pointIndex in 0..<pointCount {
            let progress = CGFloat(pointIndex) / CGFloat(pointCount - 1)
            let angle = progress * .pi * CGFloat(3.4 + Double(index % 4) * 0.6) + phase
            let knotRadius = radius * contraction * (
                0.02
                + abs(sin(progress * .pi * 4.0 + phase + time * 3.2)) * 0.34
                + abs(cos(angle * 1.7 - time * 2.8)) * 0.16
            )
            let crawl = CGPoint(
                x: sin(time * 7.0 + phase + progress * 8) * 1.8,
                y: cos(time * 6.2 + phase * 0.8 + progress * 7) * 1.5
            )
            let point = CGPoint(
                x: center.x + cos(angle) * knotRadius + crawl.x,
                y: center.y + sin(angle * 0.92) * knotRadius * 0.88 + crawl.y
            )
            points.append(point)
        }

        return hybridPath(points: points, angularSeed: index + 11)
    }

    private func makeRadialFillPath(
        index: Int,
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval
    ) -> Path {
        let pointCount = 26
        let time = CGFloat(time)
        let phase = CGFloat(index) * 0.92
        var points: [CGPoint] = []

        for pointIndex in 0..<pointCount {
            let progress = CGFloat(pointIndex) / CGFloat(pointCount - 1)
            let foldedProgress = index % 2 == 0 ? progress : 1 - progress
            let angle = phase
                + sin(progress * .pi * 3.0 + phase) * 0.84
                + cos(time * 4.8 + progress * 7 + phase) * 0.04
            let localRadius = radius * (
                0.00
                + foldedProgress * 1.05
                + sin(progress * .pi * 8 + phase + time * 5.6) * 0.035
            )
            let point = CGPoint(
                x: center.x + cos(angle) * localRadius,
                y: center.y + sin(angle) * localRadius * 0.92
            )
            points.append(point)
        }

        return hybridPath(points: points, angularSeed: index + 23)
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

    private func hybridPath(points: [CGPoint], angularSeed: Int) -> Path {
        var path = Path()
        guard points.count > 2, let first = points.first else { return path }

        path.move(to: first)

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let shouldMakeAngle = (index + angularSeed) % 5 == 0 || (index * (angularSeed + 3)) % 17 == 0

            if shouldMakeAngle {
                path.addLine(to: current)
            } else {
                let midpoint = CGPoint(
                    x: (previous.x + current.x) * 0.5,
                    y: (previous.y + current.y) * 0.5
                )
                path.addQuadCurve(to: midpoint, control: previous)
            }
        }

        if let last = points.last {
            path.addLine(to: last)
        }

        return path
    }

    private func strokeWidth(for index: Int, pass: Int, time: TimeInterval) -> CGFloat {
        let base = 1.35 + CGFloat(index % 4) * 0.12
        let livingPressure = abs(sin(CGFloat(time) * 1.18 + CGFloat(index) * 1.33 + CGFloat(pass))) * 0.28
        let recordingBoost: CGFloat = state == .recording ? 0.18 : 0
        let passWeight: CGFloat = pass == 0 ? 0.18 : 0.08
        return base + livingPressure + recordingBoost + passWeight
    }

    private func strokeOpacity(for index: Int, pass: Int, time: TimeInterval) -> Double {
        let base = pass == 0 ? 0.86 : 0.54
        let layerBoost = Double(index % 4) * 0.018
        let flutter = abs(sin(time * 1.08 + Double(index) * 0.91 + Double(pass) * 0.4)) * 0.035
        return min(0.94, base + layerBoost + flutter)
    }
}

private struct ScribblePaperBacking: View {
    var state: ScribbleEchoButtonState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let pulse = reduceMotion ? 0 : sin(time * 2.35) * 0.5 + 0.5
            Circle()
                .fill(ScribbleEchoPalette.paper.opacity(state == .recording ? 0.40 : 0.28))
                .overlay(
                    Circle()
                        .stroke(ScribbleEchoPalette.ink.opacity(0.07), lineWidth: 1)
                )
                .shadow(color: ScribbleEchoPalette.ink.opacity(state == .recording ? 0.11 : 0.07), radius: state == .recording ? 26 : 18, x: 0, y: 12)
                .scaleEffect(1 + CGFloat(pulse) * (state == .recording ? 0.045 : 0.018))
                .overlay(
                    Circle()
                        .stroke(ScribbleEchoPalette.sepia.opacity(state == .recording ? 0.13 : 0.06), lineWidth: 1.6)
                        .scaleEffect(1.05 + CGFloat(pulse) * 0.10)
                        .blur(radius: 7)
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
    static let paper = Color(red: 0.965, green: 0.945, blue: 0.895)
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
