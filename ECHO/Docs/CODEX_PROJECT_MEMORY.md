# Codex Project Memory: Echo

Read this file before making changes to Echo.

## Product Idea

Echo is an iOS SwiftUI app for building a personal cultural memory archive from voice or typed memories.

Central promise:

```text
Speak a memory. Echo turns it into a card you can keep.
```

Strong product decision:

```text
Echo does not collect posters. Echo collects what remains.
```

## MVP Flow

```text
Speak or type a memory -> Structured card -> Review -> Save -> Collection
```

The app must work offline for creating manually, saving, editing, deleting, and browsing memories.

## Collaboration Context

There are two teams:

| Team | Focus |
|---|---|
| Design team | Final UI, visual style, assets, layout polish |
| Technical team | Data, persistence, Speech, AI, permissions, error states, integration APIs |

Codex should prioritize technical architecture and plug-and-play integration points. UI should stay basic unless needed to test or expose a technical flow.

## Current Stack

- SwiftUI for UI
- SwiftData for local persistence
- `EchoMemory` as the persisted model
- `@Query` for collection reads
- `ModelContext` for insert/delete/edit persistence
- Temporary local `AIExtractionService` heuristic until FoundationModels is integrated
- Speech framework not implemented yet
- No backend
- No login
- No third-party APIs

## Important Files

- `ECHO/ECHO/Models/EchoMemory.swift`
- `ECHO/ECHO/Services/AIExtractionService.swift`
- `ECHO/ECHO/ECHOApp.swift`
- `ECHO/ECHO/Views/HomeView.swift`
- `ECHO/ECHO/Views/CaptureView.swift`
- `ECHO/ECHO/Views/ReviewCardView.swift`
- `ECHO/ECHO/Views/EditEchoView.swift`
- `ECHO/ECHO/Views/EchoDetailView.swift`
- `ECHO/ECHO/Views/Components/EchoCardView.swift`
- `ECHO/ECHO/Views/Components/EchoFormView.swift`

## Data Contract

Keep this model stable unless explicitly asked to migrate:

```swift
@Model
final class EchoMemory {
    var id: UUID
    var title: String
    var creator: String?
    var category: EchoCategory
    var emotion: EchoEmotion
    var memory: String
    var echoLine: String
    var year: String?
    var originalTranscript: String?
    var createdAt: Date
}
```

Categories:

- Film
- Book
- Music
- Painting
- Video Game
- Performance
- Place
- Object
- Other

Emotions:

- Nostalgia
- Joy
- Wonder
- Melancholy
- Calm
- Shock
- Love
- Curiosity

## Engineering Rules

- Keep changes scoped to the requested step.
- Stop after each major step so the user can discuss before continuing.
- Prefer technical stability over visual polish.
- Keep UI replaceable by the design team.
- Do not introduce a backend, account system, social feed, external media, posters, covers, or third-party cultural APIs in V1.
- Maintain offline-first behavior.
- Preserve manual text fallback even after Speech is added.
- Preserve manual review/edit fallback even after AI is added.
- Use SwiftData, not a custom JSON store.
- Use Apple documentation search before implementing newer Apple frameworks like Speech, FoundationModels, App Intents, or Liquid Glass.

## Development Order

Current agreed order:

1. SwiftData persistence. Done.
2. Stabilize the MVP SwiftData flow. Done for the SwiftData data layer; manual UI runtime test was blocked by simulator connection.
3. Add Speech transcription.
4. Add FoundationModels / Apple Intelligence structured extraction.
5. Improve error handling and fallback states.
6. Add App Intents / Siri if time allows.
7. Leave final visual polish to the design integration phase.

## What Codex Should Do Next

If the user asks to continue, start with step 3: add Speech transcription.

Before starting Speech, mention that the SwiftData data layer was validated with insert, fetch, edit, delete, and save in an isolated ModelContainer. Manual UI runtime verification should still be done in Xcode or on device when the simulator connection is available.

Do not start FoundationModels until the user confirms moving to that step.
