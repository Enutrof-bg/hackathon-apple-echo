# Echo Architecture

## Product Scope

Echo is an iOS SwiftUI MVP for capturing personal cultural memories.

Core flow:

```text
Speak or type a memory -> Generate a structured Echo card -> Review -> Save to collection
```

The app is offline-first. It must not require login, backend services, third-party APIs, poster images, covers, or public sharing in V1.

## Team Split

The project is developed by two teams:

| Team | Responsibility |
|---|---|
| Design | Final screens, visual system, assets, animation, layout polish |
| Technical | Data model, persistence, Speech, AI extraction, permissions, error handling, App Intents |

The current SwiftUI screens are intentionally basic. They exist to test technical flows and should remain easy for the design team to replace.

## Current Technical Foundation

| Area | Current Choice |
|---|---|
| UI framework | SwiftUI |
| Local persistence | SwiftData |
| Persisted data model | `EchoMemory` |
| Temporary card draft | `EchoMemoryDraft` |
| Collection loading | `@Query` |
| Create/save | `EchoMemoryPersistenceService.insert(_:in:)` |
| Move to trash | `EchoMemoryPersistenceService.moveToTrash(_:in:)` |
| Restore | `EchoMemoryPersistenceService.restore(_:in:)` |
| Permanent delete | `EchoMemoryPersistenceService.deletePermanently(_:in:)` |
| Trash purge | `EchoMemoryPersistenceService.purgeExpiredDeletedMemories(_:in:)` |
| Edit | `EchoMemoryPersistenceService.update(_:with:in:)` |
| AI extraction | Temporary local heuristic service returning `EchoMemoryDraft` |
| Speech | Not implemented yet |

## Main Files

| File | Role |
|---|---|
| `ECHOApp.swift` | App entry point and SwiftData `modelContainer` setup |
| `ContentView.swift` | Root view wrapper |
| `Models/EchoMemory.swift` | SwiftData model and category/emotion enums |
| `Models/EchoMemoryDraft.swift` | Non-persisted draft used by extraction and review flows |
| `Models/EchoUserFacingError.swift` | Shared UI-safe error payload for alerts |
| `Services/AIExtractionService.swift` | Temporary text-to-card extraction logic returning drafts |
| `Services/EchoMemoryPersistenceService.swift` | Centralized SwiftData insert/update/delete operations |
| `Views/HomeView.swift` | Basic collection view and capture entry point |
| `Views/CaptureView.swift` | Basic capture fallback using typed text |
| `Views/ReviewCardView.swift` | Review generated card before saving |
| `Views/EditEchoView.swift` | Edit an existing card |
| `Views/EchoDetailView.swift` | Detail, edit, and delete flow |
| `Views/Components/EchoCardView.swift` | Basic reusable card rendering |
| `Views/Components/EchoFormView.swift` | Basic reusable edit form |

## Model Contract

`EchoMemory` is the central persisted model.

Required fields:

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

Design-facing display fields:

- `title`
- `creator`
- `category.title`
- `category.symbolName`
- `emotion.title`
- `memory`
- `echoLine`
- `year`
- `createdAt`

## Categories

Current categories:

- Film
- Book
- Music
- Painting
- Video Game
- Performance
- Place
- Object
- Other

Each category exposes:

- `title`: display text
- `symbolName`: SF Symbol name

## Emotions

Current emotions:

- Nostalgia
- Joy
- Wonder
- Melancholy
- Calm
- Shock
- Love
- Curiosity

Each emotion exposes:

- `title`: display text

## UI Replacement Rules

The design team can replace most SwiftUI views as long as these contracts stay intact:

- Read saved memories with `@Query(sort: \EchoMemory.createdAt, order: .reverse)`.
- Use `EchoMemoryDraft` for generated or manually edited data before persistence.
- Save a new memory with `EchoMemoryPersistenceService.insert(_:in:)`.
- Delete a memory with `EchoMemoryPersistenceService.delete(_:in:)`.
- Edit an existing memory with `EchoMemoryPersistenceService.update(_:with:in:)`.
- Keep `EchoMemory`, `EchoMemoryDraft`, `EchoCategory`, and `EchoEmotion` stable unless the technical team coordinates migration changes.

Recommended reusable entry points for design:

```swift
EchoCardView(memory: memory)
ReviewCardView(memory: generatedMemory)
EditEchoView(memory: memory)
EchoDetailView(memory: memory)
```

These components may be visually redesigned without changing the data contract.

## Technical Priorities

Proceed in this order:

1. Stabilize SwiftData flow: create, save, list, detail, edit, delete.
2. Add Speech framework transcription with permission handling.
3. Keep typed text fallback for unsupported voice capture.
4. Replace the heuristic extraction service with FoundationModels / Apple Intelligence when available.
5. Keep manual fallback for AI unavailable or generation failure.
6. Add App Intents / Siri shortcut if time permits.
7. Polish implementation details after the technical flow is robust.

## Design Boundaries for Technical Team

The technical team should avoid heavy visual decisions unless needed to test a flow.

Do:

- Build simple screens that expose the flow.
- Keep components small and replaceable.
- Use native SwiftUI controls for technical validation.
- Keep copy in English, matching the product spec.

Do not:

- Spend time on final visual polish before design integration.
- Add poster images, covers, or external media.
- Add backend dependencies.
- Add login or accounts.
- Overbuild architecture for hackathon scope.

## Current Known Fallbacks

| Situation | Current Behavior |
|---|---|
| Speech unavailable | User can type the memory manually |
| AI unavailable | Local heuristic service creates a rough card |
| Empty memory | User receives an error and can still continue manually |
| No saved data | Empty state appears in collection |

## Next Technical Step

Before adding new features, verify the SwiftData MVP manually:

1. Open app.
2. Tap `Capture an Echo`.
3. Type a memory.
4. Create card.
5. Save Echo.
6. Confirm card appears in collection.
7. Open detail.
8. Edit fields.
9. Delete card.
10. Relaunch app and confirm persistence works.
