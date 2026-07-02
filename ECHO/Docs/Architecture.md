# Echo Architecture

## Product Scope

Echo is an iOS SwiftUI MVP for capturing personal cultural memories from voice or typed input.

Core promise:

```text
Speak a memory. Echo turns it into a card you can keep.
```

Product principle:

```text
Echo does not collect posters. Echo collects what remains.
```

Core flow:

```text
Speak or type a memory -> Generate a structured Echo card -> Review and edit -> Save to collection
```

The app is offline-first for manual creation, browsing, editing, deleting, restoring, and permanent deletion. V1 must not require login, backend services, third-party APIs, poster images, covers, social sharing, or public profiles.

## Team Split

| Team | Responsibility |
|---|---|
| Design | Final screens, visual system, interaction model, assets, animation, layout polish, empty/error/loading state presentation |
| Technical | Data model, SwiftData persistence, Speech capture, AI extraction, permissions, error handling, service contracts, App Intents when needed |

The current SwiftUI screens are functional scaffolding. They validate the end-to-end product flow and should remain easy for the design team to replace without changing the data and service contracts.

## Current Technical Foundation

| Area | Current Choice |
|---|---|
| App platform | iOS |
| UI framework | SwiftUI |
| App root | `ECHOApp` -> `ContentView` -> `HomeView` |
| Local persistence | SwiftData |
| Persisted model | `EchoMemory` |
| Draft/review model | `EchoMemoryDraft` |
| Card display protocol | `EchoCardPresentable` |
| Collection loading | `@Query(sort: \EchoMemory.createdAt, order: .reverse)` |
| Persistence gateway | `EchoMemoryPersistenceService` |
| AI extraction | `FoundationModels` structured generation with local heuristic fallback |
| Speech | `SpeechAnalyzer` + `DictationTranscriber` with microphone capture through `CaptureInputSequenceProvider` |
| Speech locale | Automatic from iOS preferred languages, with fallback locales |
| Speech context bias | Cultural proper names through `AnalysisContext.contextualStrings` |
| Error payload | `EchoUserFacingError` for alert-safe messages |
| Backend | None |
| Accounts | None |
| Third-party cultural APIs | None |

## Main Product Surfaces

| Surface | Current File | Purpose | Design Status |
|---|---|---|---|
| Home input | `Views/HomeView.swift` | Owns voice, text, and photo input from the first screen; saves generated Echoes and opens detail editing | Primary input shell |
| Collection | `Views/GalleryView.swift` | Shows active Echo cards and Recently Deleted entry | Replaceable shell |
| Legacy capture | `Views/CaptureView.swift` | Older full capture sheet kept for compatibility, not the primary home input route | Replaceable / candidate for cleanup |
| Review | `Views/ReviewCardView.swift` | Review flow still used by suggestions and non-home draft paths | Replaceable shell |
| Detail | `Views/EchoDetailView.swift` | Shows one saved Echo, supports starting in edit mode, inline edit, audio, links, recommendations, and move to trash | Replaceable shell |
| Edit | `Views/EditEchoView.swift` | Edits a persisted Echo through draft fields in older navigation paths | Replaceable shell |
| Recently Deleted | `Views/RecentlyDeletedView.swift` | Restores or permanently deletes soft-deleted Echoes | Replaceable shell |
| Card component | `Views/Components/EchoCardView.swift` | Shared preview/list/detail card rendering for draft and persisted memories | Primary design component |
| Form component | `Views/Components/EchoFormView.swift` | Shared editable fields for review and edit flows | Replaceable form pattern |

## User Journey

1. User lands on `HomeView`, which presents the central voice button plus text and photo alternatives.
2. Voice input stays on `HomeView`: the central button animates while listening, transcript text is not shown, and tapping again finishes capture.
3. Text input opens a compact `TextEchoInputSheet`; the submit button is pinned with `safeAreaInset` so the keyboard cannot cover it.
4. Photo input opens `CameraImagePicker` directly, then scans the image through `EchoCoverScanService`.
5. Voice and text send transcript text through `AIExtractionService`; photo sends the image through Apple Intelligence image analysis with Vision OCR fallback.
6. Each path creates an `EchoMemoryDraft`, saves it through `EchoMemoryPersistenceService.insert(_:in:)`, and creates graph links with `EchoMemoryLinkService`.
7. The app navigates immediately to `EchoDetailView(startsEditing: true)` so the user edits the prefilled saved Echo.
8. Collection reloads through SwiftData `@Query`.
9. User can later open detail, edit, move to Recently Deleted, undo the move, restore, or permanently delete.

## Model Contract

`EchoMemory` is the central persisted model. Keep it stable unless the technical team coordinates a SwiftData migration.

```swift
@Model
final class EchoMemory {
    var id: UUID
    var title: String
    var creator: String?
    var category: EchoCategory
    var emotion: EchoEmotion
    var memory: String
    var year: String?
    var originalTranscript: String?
    var audioFileName: String?
    var audioDuration: TimeInterval?
    var createdAt: Date
    var deletedAt: Date?
}
```

Design-facing fields:

| Field | Meaning | UI Notes |
|---|---|---|
| `title` | Work, place, object, or remembered moment | Primary card title |
| `creator` | Creator/artist/author if known | Optional metadata |
| `category.title` | Human-readable category | Can be label, chip, section, icon pairing |
| `category.symbolName` | SF Symbol for the category | Current icon source |
| `emotion.title` | Dominant feeling | Can drive color, tone, grouping, or filter design |
| `memory` | Personal memory text | Main body content |
| `year` | Optional year | Metadata only |
| `originalTranscript` | Raw captured input | Internal/debug/reference; not required in primary UI |
| `audioFileName` | Local voice recording file name | Optional; present only for spoken Echoes |
| `audioDuration` | Recorded voice duration in seconds | Optional playback metadata |
| `createdAt` | Save date | Collection/detail metadata |
| `deletedAt` | Soft-delete date | Recently Deleted state and retention |

`EchoMemoryDraft` mirrors the display fields before persistence. It is used for AI output, review, edit forms, and conversion into `EchoMemory`.

## Categories

Current categories are fixed enum cases in `EchoCategory`:

| Category | SF Symbol |
|---|---|
| Film | `film` |
| Book | `book.closed` |
| Music | `music.note` |
| Painting | `paintpalette` |
| Video Game | `gamecontroller` |
| Performance | `theatermasks` |
| Place | `mappin.and.ellipse` |
| Object | `cube` |
| Other | `sparkle` |

Design can change visual treatment, grouping, color, and icon presentation. Renaming, removing, or adding categories affects extraction, persistence, and possible migration work.

## Emotions

Current emotions are fixed enum cases in `EchoEmotion`:

- Nostalgia
- Joy
- Wonder
- Melancholy
- Calm
- Shock
- Love
- Curiosity

Current `EchoCardView` maps emotions to system colors only as placeholder styling. Design can replace this with a final emotional color/token system, but should keep every emotion visually distinct enough for scanning.

## State Model for Design

| Area | States Design Should Cover |
|---|---|
| Collection | Empty, populated, search active, no search results, purge error |
| Home input | Idle, voice listening, voice finishing, text sheet open, camera open, AI creating, save failed |
| Speech | Idle, requesting permission, ready, listening, unavailable, failed; transcript stays hidden in the primary UI |
| Text popup | Empty, typing, keyboard visible, processing, submit disabled/enabled |
| Photo input | Camera open, photo selected, Apple Intelligence scanning, Vision OCR fallback, manual correction needed |
| Card generation | Idle, creating, failed/heuristic fallback implied by resulting editable detail |
| Detail | Starts in edit mode after input, active memory, moved-to-trash undo bubble, delete error |
| Edit | Editing, save error |
| Recently Deleted | Empty, populated, restore error, permanent delete error |
| Permissions | Microphone denied, microphone unavailable, speech unavailable |

Manual text entry is not an edge case. It is a first-class fallback and must remain available when speech fails, permissions are denied, language assets are unavailable, or the user simply prefers typing.

## Current Services

| File | Role |
|---|---|
| `Services/AIExtractionService.swift` | Converts transcript text into `EchoMemoryDraft`; tries FoundationModels first, falls back to local heuristic extraction |
| `Services/EchoMemoryPersistenceService.swift` | Central insert, update, move-to-trash, restore, permanent-delete, and purge operations |
| `Services/SpeechTranscriptionService.swift` | Main speech state machine, permission request, analyzer setup, transcript updates, audio attachment handoff, errors |
| `Services/EchoAudioRecordingService.swift` | Writes spoken capture audio to local `.m4a` files and resolves/deletes recording files |
| `Services/SpeechCaptureSessionController.swift` | Actor that starts/stops the underlying `AVCaptureSession` safely |
| `Services/SpeechRecognitionLocaleProvider.swift` | Chooses a supported dictation locale from preferred languages and fallbacks |
| `Services/SpeechRecognitionContextProvider.swift` | Provides cultural terms to bias recognition of names and titles |

## Persistence and Deletion

Saved Echoes are never directly removed from the main collection by the detail delete action. They are soft-deleted by setting `deletedAt`.

| Action | Service Method | Behavior |
|---|---|---|
| Save new Echo | `insert(_:in:)` | Converts draft to `EchoMemory`, inserts, saves context |
| Edit Echo | `update(_:with:in:)` | Sanitizes draft, updates fields, saves context |
| Move to trash | `moveToTrash(_:in:)` | Sets `deletedAt`, saves context |
| Undo/restore | `restore(_:in:)` | Clears `deletedAt`, saves context |
| Delete permanently | `deletePermanently(_:in:)` | Deletes object from SwiftData, saves context, then deletes the local voice file |
| Purge expired trash | `purgeExpiredDeletedMemories(_:in:)` | Deletes memories soft-deleted for 30+ days and removes their local voice files |

`HomeView` filters active memories with `deletedAt == nil`. `RecentlyDeletedView` receives memories where `deletedAt != nil`.

## UI Replacement Rules

The design team can replace the current SwiftUI visuals as long as these contracts stay intact:

- Read saved memories with SwiftData query sorted by `createdAt` descending.
- Filter the main collection to memories where `deletedAt == nil`.
- Use `EchoMemoryDraft` for generated/review/editable data before saving.
- Save new memories with `EchoMemoryPersistenceService.insert(_:in:)`.
- Update existing memories with `EchoMemoryPersistenceService.update(_:with:in:)`.
- Move memories to Recently Deleted with `EchoMemoryPersistenceService.moveToTrash(_:in:)`.
- Restore with `EchoMemoryPersistenceService.restore(_:in:)`.
- Permanently delete with `EchoMemoryPersistenceService.deletePermanently(_:in:)`.
- Keep `EchoMemory`, `EchoMemoryDraft`, `EchoCategory`, and `EchoEmotion` stable unless migration work is coordinated.
- Preserve the review step before persistence.
- Preserve manual editing of AI-generated output.
- Preserve typed input as a fallback and as an explicit mode.

Recommended reusable entry points while redesigning:

```swift
EchoCardView(memory: memory)
ReviewCardView(draft: draft)
EditEchoView(memory: memory)
EchoDetailView(memory: memory)
RecentlyDeletedView(memories: deletedMemories)
```

These can be visually redesigned or replaced, but the data flow should remain the same.

## Design Integration Notes

The product should feel like a personal cultural archive, not a media database. The UI should prioritize the user memory, emotion, and retained meaning over external artwork or catalog metadata.

Design should define:

- Final card hierarchy for title, creator, category, emotion, echo line, and memory text.
- Emotion/category visual language.
- Capture interaction for voice, including recording affordance and live transcript behavior.
- Review/edit interaction that makes AI output feel correctable, not final.
- Empty states for collection and Recently Deleted.
- Error and permission states that keep typing available.
- Search results and no-results state.
- Trash/undo/restore affordances.
- Motion rules for sheet transitions, recording state, card creation, and undo bubble.

Avoid in V1:

- Poster or cover dependency.
- External cultural catalog lookups.
- Social feed or sharing surfaces.
- Account/login onboarding.
- Heavy onboarding before the user can capture an Echo.

## Technical Priorities

Current foundation:

1. SwiftData persistence is implemented.
2. Main create, review, save, list, detail, edit, soft-delete, restore, and permanent-delete flows exist.
3. Speech transcription is implemented with modern Speech APIs and typed fallback.
4. FoundationModels structured extraction is implemented with heuristic fallback.

Next technical work should focus on:

1. Runtime validation on a real device for microphone permission, dictation language assets, and Speech behavior.
2. Manual QA of create, edit, delete, restore, purge, and relaunch persistence.
3. Better visible fallback messaging when FoundationModels is unavailable and heuristic extraction was used.
4. App Intents / Siri only after the MVP capture flow is stable.
5. Design integration of the replaceable SwiftUI screens.

## Manual QA Checklist

Use this checklist before or during design integration:

1. Open app with no saved data and verify collection empty state.
2. Tap capture.
3. Switch between `Speak` and `Type`.
4. Deny microphone permission and confirm typing remains usable.
5. Type a memory and create a card.
6. Review the generated card.
7. Edit title, creator, category, emotion, memory, echo line, and year.
8. Save Echo.
9. Confirm the card appears in collection.
10. Search by title, memory, echo line, category, and emotion.
11. Open detail.
12. Edit saved Echo and confirm updates persist.
13. Move Echo to Recently Deleted.
14. Use undo from detail.
15. Move it again and let the detail dismiss.
16. Open Recently Deleted.
17. Restore Echo and confirm it returns to collection.
18. Move it again and delete permanently.
19. Relaunch app and confirm persistence state is correct.
