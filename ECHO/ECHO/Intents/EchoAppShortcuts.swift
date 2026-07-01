import AppIntents

struct EchoAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenCaptureIntent(),
            phrases: [
                "Capture an Echo in \(.applicationName)",
                "Open capture in \(.applicationName)",
                "Record an Echo in \(.applicationName)"
            ],
            shortTitle: "Capture Echo",
            systemImageName: "waveform"
        )

        AppShortcut(
            intent: CreateEchoIntent(),
            phrases: [
                "Add an Echo in \(.applicationName)",
                "Create an Echo in \(.applicationName)",
                "Save an Echo in \(.applicationName)"
            ],
            shortTitle: "Add Echo",
            systemImageName: "plus.bubble"
        )
    }
}
