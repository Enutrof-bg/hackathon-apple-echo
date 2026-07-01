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
            intent: OpenVoiceCaptureIntent(),
            phrases: [
                "Start a voice Echo in \(.applicationName)",
                "Listen for an Echo in \(.applicationName)",
                "Add an Echo by voice in \(.applicationName)"
            ],
            shortTitle: "Voice Echo",
            systemImageName: "mic.circle"
        )

        AppShortcut(
            intent: OpenCameraCaptureIntent(),
            phrases: [
                "Scan an Echo cover in \(.applicationName)",
                "Open camera capture in \(.applicationName)",
                "Capture an Echo cover in \(.applicationName)"
            ],
            shortTitle: "Scan Cover",
            systemImageName: "camera.viewfinder"
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

        AppShortcut(
            intent: SearchEchoesIntent(),
            phrases: [
                "Search Echoes in \(.applicationName)",
                "Find an Echo in \(.applicationName)",
                "Search my Echoes in \(.applicationName)"
            ],
            shortTitle: "Search Echoes",
            systemImageName: "magnifyingglass"
        )

        AppShortcut(
            intent: ReadSearchResultsIntent(),
            phrases: [
                "Read Echo search results in \(.applicationName)",
                "Read my Echo results in \(.applicationName)",
                "Tell me Echo results in \(.applicationName)"
            ],
            shortTitle: "Read Results",
            systemImageName: "speaker.wave.2"
        )

        AppShortcut(
            intent: MarkEchoDiscoveredIntent(),
            phrases: [
                "Mark an Echo as discovered in \(.applicationName)",
                "Set an Echo as discovered in \(.applicationName)",
                "I discovered an Echo in \(.applicationName)"
            ],
            shortTitle: "Mark Discovered",
            systemImageName: "checkmark.circle"
        )
    }
}
