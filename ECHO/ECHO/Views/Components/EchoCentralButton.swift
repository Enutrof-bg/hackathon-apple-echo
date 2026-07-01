import SwiftUI

struct EchoCentralButton: View {
    var isRecording = false
    var audioLevel: CGFloat = 0
    var size: CGFloat = 238
    var onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isPressed = false
    @State private var rippleTrigger = 0
    @State private var scribblePhase = 0.0
    @State private var breathing = false

    private var normalizedLevel: CGFloat {
        min(max(audioLevel, 0), 1)
    }

    private var activity: CGFloat {
        if isPressed { return 1 }
        if isRecording { return max(0.42, normalizedLevel) }
        return breathing ? 0.34 : 0.18
    }

    var body: some View {
        ZStack {
            ScribbleHalo(
                phase: scribblePhase,
                activity: activity,
                isRecording: isRecording
            )
            .frame(width: size * 1.22, height: size * 1.22)
            .opacity(reduceMotion ? 0.34 : 1)

            RippleEffect(trigger: rippleTrigger, color: ScribblePalette.ripple)
                .frame(width: size * 1.18, height: size * 1.18)

            AudioScribbleObject(
                phase: scribblePhase,
                activity: reduceMotion ? 0.22 : activity,
                isPressed: isPressed,
                isRecording: isRecording
            )
            .frame(width: size, height: size)
            .scaleEffect(isPressed ? 0.94 : (breathing && !reduceMotion ? 1.025 : 1))
            .animation(.spring(response: 0.24, dampingFraction: 0.62), value: isPressed)
            .animation(.easeInOut(duration: 1.8), value: breathing)
        }
        .frame(width: size * 1.35, height: size * 1.35)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    withAnimation(.spring(response: 0.20, dampingFraction: 0.64)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    handleTap()
                }
        )
        .accessibilityLabel(isRecording ? "Stop recording an Echo" : "Start recording an Echo")
        .accessibilityValue(isRecording ? "Recording in progress" : "Ready to record")
        .accessibilityHint(isRecording ? "Double tap to stop voice capture." : "Double tap to start capturing a voice memory.")
        .accessibilityAddTraits(.isButton)
        .sensoryFeedback(.selection, trigger: rippleTrigger)
        .onAppear(perform: startScribbleAnimation)
        .onChange(of: isRecording) { _, _ in
            startScribbleAnimation()
        }
    }

    private func handleTap() {
        rippleTrigger += 1

        guard !reduceMotion else {
            onTap()
            return
        }

        withAnimation(.spring(response: 0.20, dampingFraction: 0.68)) {
            isPressed = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(105))
            withAnimation(.spring(response: 0.46, dampingFraction: 0.58)) {
                isPressed = false
            }
            onTap()
        }
    }

    private func startScribbleAnimation() {
        guard !reduceMotion else { return }

        withAnimation(.linear(duration: isRecording ? 0.82 : 1.65).repeatForever(autoreverses: false)) {
            scribblePhase += 1
        }

        withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
            breathing.toggle()
        }
    }
}

private struct AudioScribbleObject: View {
    var phase: Double
    var activity: CGFloat
    var isPressed: Bool
    var isRecording: Bool

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(size.width, size.height) * (isPressed ? 0.33 : 0.36)
            let lineCount = isRecording ? 15 : 12

            for index in 0..<lineCount {
                let path = scribblePath(
                    index: index,
                    center: center,
                    radius: radius,
                    phase: phase,
                    activity: activity,
                    size: size
                )

                let opacity = 0.48 + Double((index % 5)) * 0.085
                let width = 2.0 + CGFloat(index % 4) * 0.72 + activity * 1.7
                let blur = index % 6 == 0 ? 0.45 : 0

                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: blur))
                    layer.stroke(
                        path,
                        with: .color(ScribblePalette.ink.opacity(opacity)),
                        style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
                    )
                }
            }

            let core = Path(ellipseIn: CGRect(
                x: center.x - radius * 0.52,
                y: center.y - radius * 0.46,
                width: radius * 1.04,
                height: radius * 0.92
            ))
            context.stroke(
                core,
                with: .color(ScribblePalette.ink.opacity(0.18 + Double(activity) * 0.16)),
                style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
            )
        }
        .shadow(color: ScribblePalette.ink.opacity(isRecording ? 0.22 : 0.14), radius: 12, x: 0, y: 8)
        .overlay(surfaceNoise.opacity(0.18 + Double(activity) * 0.16))
    }

    private var surfaceNoise: some View {
        Canvas { context, size in
            for index in 0..<74 {
                let seed = CGFloat(index)
                let x = abs(sin(seed * 14.12 + phase)) * size.width
                let y = abs(cos(seed * 9.77 + phase * 0.7)) * size.height
                let diameter = 0.7 + abs(sin(seed * 2.41)) * 1.7
                let rect = CGRect(x: x, y: y, width: diameter, height: diameter)
                context.fill(Path(ellipseIn: rect), with: .color(ScribblePalette.ink.opacity(0.16)))
            }
        }
        .blendMode(.multiply)
    }

    private func scribblePath(
        index: Int,
        center: CGPoint,
        radius: CGFloat,
        phase: Double,
        activity: CGFloat,
        size: CGSize
    ) -> Path {
        let points = 34
        var path = Path()
        let indexPhase = CGFloat(index) * 0.73
        let phase = CGFloat(phase) * .pi * 2
        let horizontalBias = 1.08 + CGFloat(index % 3) * 0.05
        let verticalBias = 0.88 + CGFloat((index + 1) % 4) * 0.05
        let jitter = 0.16 + activity * 0.38

        for pointIndex in 0..<points {
            let progress = CGFloat(pointIndex) / CGFloat(points - 1)
            let angle = progress * .pi * 2 * (1.0 + CGFloat(index % 4) * 0.045) + indexPhase
            let waveA = sin(angle * 2.1 + phase + indexPhase) * jitter
            let waveB = cos(angle * 3.7 - phase * 0.74 + indexPhase) * jitter * 0.62
            let voiceKick = sin(progress * .pi * 8 + phase * 1.8 + indexPhase) * activity * 0.18
            let localRadius = radius * (0.76 + waveA + waveB + voiceKick)
            let driftX = sin(phase * 0.37 + indexPhase) * radius * 0.12 * activity
            let driftY = cos(phase * 0.41 + indexPhase) * radius * 0.10 * activity
            let x = center.x + cos(angle) * localRadius * horizontalBias + driftX
            let y = center.y + sin(angle) * localRadius * verticalBias + driftY
            let point = CGPoint(x: x, y: y)

            if pointIndex == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }
}

private struct ScribbleHalo: View {
    var phase: Double
    var activity: CGFloat
    var isRecording: Bool

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let baseRadius = min(size.width, size.height) * (0.30 + activity * 0.05)

            for index in 0..<5 {
                var path = Path()
                let phase = CGFloat(phase) * .pi * 2 + CGFloat(index) * 0.9
                let rect = CGRect(
                    x: center.x - baseRadius * (1.02 + CGFloat(index) * 0.05),
                    y: center.y - baseRadius * (0.88 + CGFloat(index) * 0.04),
                    width: baseRadius * 2.0 * (1.02 + CGFloat(index) * 0.05),
                    height: baseRadius * 1.8 * (0.88 + CGFloat(index) * 0.04)
                )
                path.addEllipse(in: rect.offsetBy(
                    dx: sin(phase) * 5 * activity,
                    dy: cos(phase * 0.8) * 5 * activity
                ))
                context.stroke(
                    path,
                    with: .color(ScribblePalette.ink.opacity(isRecording ? 0.10 : 0.055)),
                    style: StrokeStyle(lineWidth: 1.1 + activity, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .blur(radius: isRecording ? 5.5 : 7.5)
    }
}

struct RippleEffect: View {
    var trigger: Int
    var color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 0.2
    @State private var opacity: Double = 0
    @State private var previousTrigger = 0

    var body: some View {
        Circle()
            .stroke(color.opacity(opacity), lineWidth: 1.4)
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
        opacity = 0.64
        withAnimation(.easeOut(duration: 0.62)) {
            scale = 1
            opacity = 0
        }
    }
}

private enum ScribblePalette {
    static let ink = Color(red: 0.015, green: 0.014, blue: 0.013)
    static let ripple = Color(red: 0.045, green: 0.043, blue: 0.040)
}

#Preview {
    ZStack {
        EchoStyle.background.ignoresSafeArea()
        VStack(spacing: 28) {
            EchoCentralButton(isRecording: false) {}
            EchoCentralButton(isRecording: true, audioLevel: 0.84, size: 180) {}
        }
    }
}
