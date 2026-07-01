# Codex Project Memory: Echo

Read this file before making changes to Echo. It is the compressed project context for future Codex conversations.

## Product Summary

Echo is an iOS SwiftUI app for building a personal cultural memory archive from spoken or typed memories.

Central promise:

```text
Speak a memory. Echo turns it into a card you can keep.
```

Strong product decision:

```text
Echo does not collect posters. Echo collects what remains.
```

Echo captures what stayed emotionally with the user about a film, book, song, place, painting, game, performance, object, or moment. It does not try to become IMDb, Spotify, Goodreads, or a poster collection.

## Product Scope

This is a hackathon MVP.

Core flow:

```text
Speak or type a memory -> AI creates a structured card -> Review -> Save -> Collection
```

V1 constraints:

- iOS app.
- SwiftUI UI.
- English app copy.
- Offline-first for creating manually, saving, editing, deleting, restoring, and browsing memories.
- No backend.
- No account system.
- No social feed.
- No poster, cover, or external media images.
- No third-party cultural APIs in V1.
- Use Apple technologies where useful: SwiftData, SpeechAnalyzer, FoundationModels / Apple Intelligence, optional App Intents later.

## Collaboration Context

There are two teams:

| Team | Focus |
|---|---|
| Design team | Final screens, visual system, layout, polish, assets, animation |
| Technical team | Data model, persistence, Speech, AI extraction, permissions, error handling, app integration points |

Codex should prioritize technical stability and plug-and-play integration points. Current SwiftUI UI is intentionally basic and can be replaced by the design team. Avoid visual polish unless needed to expose or test a technical flow.

## Current Stack

- SwiftUI for UI.
- SwiftData for local persistence.
- `EchoMemory` as the persisted SwiftData model, including `discoveryStatus` for discovered vs. not-yet-discovered cards.
- `EchoMemoryDraft` as the non-persisted review/generation model.
- `@Query` for collection reads.
- `EchoMemoryPersistenceService` for insert/update/soft-delete/restore/permanent-delete/purge operations.
- `AIExtractionService` uses FoundationModels / Apple Intelligence guided generation when available, then falls back to local heuristic extraction.
- `EchoMemoryStoredLink` persists graph edges between Echoes by source/target UUID, basis, reason, confidence, and creation date.
- `EchoMemoryLinkService` stores local heuristic links immediately when a new Echo is saved; FoundationModels is used only for non-blocking enriched suggestions/fallback display.
- Debug builds expose `Load Sample Echoes`, which inserts fixed placeholders and adds generated sample Echoes through FoundationModels when Apple Intelligence is available.
- `SpeechTranscriptionService` uses `SpeechAnalyzer` + `DictationTranscriber`.
- Spoken Echoes can persist the original voice as a local `.m4a` recording referenced by `audioFileName` and `audioDuration`.
- Microphone capture uses `CaptureInputSequenceProvider` managed by `SpeechCaptureSessionController`, not `AVAudioEngine.installTap`.
- Speech supports explicit `Speak` and `Type` modes.
- Recognition locale is selected from iOS preferred languages through `SpeechRecognitionLocaleProvider`.
- Proper-name recognition is biased with `SpeechRecognitionContextProvider` and `AnalysisContext.contextualStrings`, including active saved Echo titles and creators passed from `HomeView` into `CaptureView`.

## Important Files

- `ECHO/ECHO/Info.plist`
- `ECHO/ECHO/Models/EchoMemory.swift`
- `ECHO/ECHO/Models/EchoMemoryDraft.swift`
- `ECHO/ECHO/Models/EchoMemoryLink.swift`
- `ECHO/ECHO/Models/EchoMemoryStoredLink.swift`
- `ECHO/ECHO/Models/EchoUserFacingError.swift`
- `ECHO/ECHO/Models/CaptureInputMode.swift`
- `ECHO/ECHO/Services/AIExtractionService.swift`
- `ECHO/ECHO/Services/EchoMemoryLinkService.swift`
- `ECHO/ECHO/Services/EchoMemoryPersistenceService.swift`
- `ECHO/ECHO/Services/SpeechTranscriptionService.swift`
- `ECHO/ECHO/Services/SpeechCaptureSessionController.swift`
- `ECHO/ECHO/Services/SpeechRecognitionContextProvider.swift`
- `ECHO/ECHO/Services/SpeechRecognitionLocaleProvider.swift`
- `ECHO/ECHO/ECHOApp.swift`
- `ECHO/ECHO/ContentView.swift`
- `ECHO/ECHO/Views/HomeView.swift`
- `ECHO/ECHO/Views/CaptureView.swift`
- `ECHO/ECHO/Views/ReviewCardView.swift`
- `ECHO/ECHO/Views/EditEchoView.swift`
- `ECHO/ECHO/Views/EchoDetailView.swift`
- `ECHO/ECHO/Views/RecentlyDeletedView.swift`
- `ECHO/ECHO/Views/Components/EchoCardView.swift`
- `ECHO/ECHO/Views/Components/EchoFormView.swift`
- `ECHO/Docs/Architecture.md`
- `ECHO/Docs/CODEX_PROJECT_MEMORY.md`

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
    var year: String?
    var originalTranscript: String?
    var audioFileName: String?
    var audioDuration: TimeInterval?
    var createdAt: Date
    var deletedAt: Date?
}
```

`deletedAt == nil` means active memory. `deletedAt != nil` means recently deleted / trash.

`EchoMemoryDraft` is the non-persistent intermediate object used for generated cards and edit/review screens. It should be converted to `EchoMemory` only when saving.

## Categories

Current V1 categories:

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

- `title`
- `symbolName`

## Emotions

Current V1 emotions:

- Nostalgia
- Joy
- Wonder
- Melancholy
- Calm
- Shock
- Love
- Curiosity

Each emotion exposes:

- `title`

## Implemented Features

### SwiftData Persistence

Done.

The app persists Echo cards locally with SwiftData. There is no backend and no account system.

### Home / Collection

Done in basic technical UI.

`HomeView` displays active memories, search, capture entry points, and a navigation link to recently deleted memories.

`HomeView` separates memories like this:

```swift
private var activeMemories: [EchoMemory] {
    memories.filter { $0.deletedAt == nil }
}

private var deletedMemories: [EchoMemory] {
    memories.filter { $0.deletedAt != nil }
}
```

`HomeView` passes active saved memories into capture:

```swift
CaptureView(existingMemories: activeMemories)
```

### Capture: Speak or Type

Done.

`CaptureInputMode` supports explicit `Speak` and `Type` modes. Text mode is not merely a fallback; it is a first-class capture path.

### Review / Save / Edit / Detail

Done.

Views involved:

- `ReviewCardView`
- `EditEchoView`
- `EchoDetailView`
- `EchoFormView`
- `EchoCardView`

The user can review a generated card, edit fields, save, open detail, edit later, and delete.

### Recently Deleted / Trash

Done.

Deleting from detail moves an Echo to Recently Deleted by setting `deletedAt`.

Supported behavior:

- soft delete;
- restore;
- permanent delete;
- automatic purge after 30 days;
- undo bubble for 4 seconds after delete from detail.

Persistence logic is centralized in `EchoMemoryPersistenceService`.

### Speech-to-Text

Done.

Current architecture:

- `SpeechTranscriptionService`
- `EchoAudioRecordingService`
- `SpeechCaptureSessionController`
- `SpeechRecognitionLocaleProvider`
- `SpeechRecognitionContextProvider`

Current Apple APIs:

- `SpeechAnalyzer`
- `DictationTranscriber`
- `CaptureInputSequenceProvider`
- `AVCaptureAudioDataOutput`
- `AVAssetWriter`
- `AnalysisContext.contextualStrings`

Do not revert to `AVAudioEngine.installTap`; it was removed because it is deprecated in iOS 27.

`SpeechCaptureSessionController` is an actor that keeps blocking `AVCaptureSession.startRunning()` / `stopRunning()` work off the MainActor.

### Speech Locale Selection

Done.

`SpeechRecognitionLocaleProvider` selects a supported dictation locale from the user's preferred iOS languages, with fallbacks including:

- `fr-FR`
- `en-US`
- `en-GB`
- `es-ES`
- `de-DE`
- `it-IT`

### Speech Proper-Name Context

Done.

`SpeechRecognitionContextProvider` builds contextual strings from:

- default cultural terms;
- active saved Echo titles;
- active saved Echo creators.

`CaptureView` updates the speech service right before recording:

```swift
transcriptionService.updateContextualStrings(
    SpeechRecognitionContextProvider.contextualStrings(from: existingMemories)
)
```

Apple guidance: keep contextual strings short, ideally one or two words, and limit total phrases to about 100. The provider normalizes, deduplicates, and caps terms.

### FoundationModels / Apple Intelligence

Done.

`AIExtractionService` uses FoundationModels guided generation when available.

Current flow:

```text
Transcript -> EchoTitleExtractionService deterministic title candidate
           -> FoundationModels guided generation with title hint -> EchoMemoryDraft
           -> local heuristic fallback if model unavailable or generation fails
```

`EchoTitleExtractionService` handles short title-intent phrases before Apple Intelligence, including one-word and multi-word titles such as `j'aimerais lire l'alchimiste`, `j'aimerais lire cent ans de solitude`, and `je veux regarder le voyage de chihiro`. It also splits author separators such as `de`, `d'`, `d’`, `par`, and `by`, so `l'alchimiste de paulo coelho` becomes title `L'Alchimiste` and creator `Paulo Coelho`, while avoiding obvious false splits like `Le nom de la rose`. The deterministic title candidate is passed to FoundationModels as a hint and used as a post-processing guardrail when the model omits or weakens the title.

`SystemLanguageModel.default` is checked before use. The app still works when Apple Intelligence is unavailable.

### Discover Section

Done in basic technical UI.

`ContentView` now uses a `TabView` with:

- `HomeView` for the saved Echo archive;
- `DiscoverView` for saved discovery queue, hardcoded new suggestions, and rediscovery.

Discover architecture:

- `EchoDiscoverySuggestion` is the runtime display model for new suggested works not yet saved.
- `EchoDiscoverySuggestionProviding` is the provider interface.
- `EchoDiscoveryService` owns queue, rediscover, and suggestion filtering.
- `HardcodedEchoDiscoverySuggestionProvider` currently returns curated hardcoded suggestions.

`DiscoverView` sections:

- `Your Queue`: active saved Echoes where `discoveryStatus == .notDiscovered`;
- `New Suggestions`: hardcoded suggestions, filtered to avoid titles already in the archive;
- `Rediscover`: older saved discovered Echoes.

Selecting a hardcoded suggestion opens `ReviewCardView` with an `EchoMemoryDraft`, so the user can review/edit/save it as a real Echo. The provider boundary is intended to be replaced later by PCC, embeddings, or another recommendation algorithm without rewriting Discover UI.

### Local Recommendations

Done in basic technical UI.

Echo now has a recommendation layer for not-yet-discovered cards:

- `EchoRecommendation` is the runtime display model.
- `EchoRecommendationBasis` describes why a recommendation appears.
- `EchoRecommendationProviding` is the provider interface.
- `EchoRecommendationService` owns display limits and filtering.
- `LocalEchoRecommendationProvider` is the current hardcoded/local algorithm.

Current local behavior:

- recommends only active `notDiscovered` Echoes;
- excludes the current Echo;
- scores by shared emotion, category, creator, year, and memory keywords;
- displays up to 3 recommendations in `EchoDetailView` under `Recommended Next`;
- keeps recommendations separate from `Related Echoes`, which remains the memory graph.

Architecture note: the provider boundary is intentionally present so a future PCC, embedding, API, or curated recommendation engine can replace `LocalEchoRecommendationProvider` without rewriting `EchoDetailView`.

### Smart Local Search

Done in basic technical UI.

`HomeView` uses `EchoSearchService` instead of simple substring filtering. Search remains local and instant, with scoring across title, creator, category, emotion, discovery status, year, memory text, and echo line. The service also parses lightweight search intent from English/French query terms, including:

- category, such as film/book/music/place;
- emotion, such as sad/triste/solitude -> `melancholy`;
- discovery status, such as `pas encore`, `a decouvrir`, `watchlist`, or `reading list` -> `notDiscovered`;
- year queries;
- theme aliases such as winter/hiver, family/famille, rain/pluie.

Apple Intelligence is not in the search path yet; keep the search deterministic and offline-first unless a future step explicitly adds async query interpretation.

### Not-Yet-Discovered Cards

Done in basic technical UI.

Echo supports greyed cards for works, places, objects, or performances the user has not discovered yet. For SwiftData migration safety, the persisted field is the optional raw value and the app uses a computed status fallback:

```swift
var discoveryStatusRawValue: String?
@Transient var discoveryStatus: EchoDiscoveryStatus
```

Current statuses:

- `discovered`
- `notDiscovered`

`EchoCardView` renders `notDiscovered` cards with a grey background and a `Not discovered yet` badge. `EchoFormView` exposes a status picker so users can correct the state manually. `AIExtractionService` asks FoundationModels to identify future-intent language and local fallback detects common English/French patterns such as `I want to read...` and `j'aimerais lire...`.

### Related Echo Graph

Done in basic technical UI.

`ReviewCardView` creates graph links when a new Echo is saved. The feature uses:

- `EchoMemoryLink` as a runtime display link model;
- `EchoMemoryStoredLink` as the persisted SwiftData graph edge with source UUID, target UUID, basis, reason, confidence, score, and creation date;
- `EchoMemoryLinkService` for link generation, storage, display filtering, refresh, rebuild, and cleanup;
- local scoring and reason composition for reliable signals such as shared emotion, category, creator, year, and memory keywords;
- FoundationModels guided generation when available to improve suggested reasons across top candidates.

`EchoDetailView` reads persisted graph edges first. If an older Echo has no stored links yet, it falls back to runtime suggestions.

Graph limits:

- store up to 10 links per Echo, enforced across both source and target endpoints of each stored edge;
- merge new candidates with existing stored links and keep the strongest 10, allowing stronger new links to replace weak old links;
- show up to 5 links in `Related Echoes`;
- hide links with score below 3 from the detail view;
- if stored links exist but none meet display threshold, `EchoDetailView` attempts runtime suggestions before showing the debug empty state;
- debug UI shows displayed/available counts plus score, confidence, and basis.

Graph maintenance behavior:

- creating an Echo stores local heuristic links immediately without waiting for Apple Intelligence;
- editing an Echo refreshes local heuristic stored links immediately;
- permanent delete and trash purge remove related stored links;
- soft-deleted Echoes are ignored by display and generation;
- debug builds expose `Rebuild Echo Links` to regenerate the stored graph over active Echoes.

Targeted snippet validation covered link creation, displayed-link filtering, weak-link replacement, rebuild cleanup, duplicate-edge prevention, deleted-memory exclusion, delete cleanup, and the per-Echo 10-link cap after dense rebuilds.

Product rule: Apple Intelligence suggestions may use general cultural understanding only as tentative thematic inference. Do not present model-inferred cultural knowledge as fact. Factual links must come from user-provided fields or a future reliable data source.

### User-Facing Error States

Done in basic technical UI.

Current behavior:

- Speech errors use stable, actionable messages and always point to Type mode as fallback.
- Speech capture has a `stopping` state so the UI does not appear ready while audio teardown is still in progress.
- Speech transcription accumulates finalized result phrases and keeps volatile text separate, preventing long dictation from replacing or clearing earlier transcript text. Targeted snippet validation covered finalized preservation, volatile replacement, reset, and resume with visible text.
- Apple Intelligence / FoundationModels fallback is surfaced in `CaptureView` after local card generation.
- Persistence alerts use generic local-storage messages instead of raw system error descriptions.
- Manual review/edit remains available after fallback generation.

### Summary Field Removal

Done.

Echo no longer keeps a separate summary field. The former persisted `echoLine`/`Summary` concept has been removed from the model, draft contract, FoundationModels schema, local fallback, forms, cards, detail view, widgets, search, and link prompts.

Rules:

- do not generate a summary or tagline;
- use `memory` as the single user-facing remembered text;
- do not keep a hidden summary in app state or persistence;
- cards and detail views should prioritize title, creator, category, emotion, memory, year, and discovery status.

### AI Anti-Hallucination Recalibration

Done.

Reason: testing showed that with vague or noisy input, Apple Intelligence could produce weird invented details.

Current generated schema behavior:

- `title: String?`
- `creator: String?`
- `year: String?`
- `category`: generated enum
- `emotion`: generated enum
- `confidence`: generated enum (`high`, `medium`, `low`)

If confidence is low, the app forces:

```text
title = Untitled Echo
creator = nil
year = nil
```

The service cleans placeholder values such as:

- `unknown`
- `uncertain`
- `unspecified`
- `not mentioned`
- `not known`
- `none`
- `nil`
- `null`
- `n/a`
- `na`
- `-`

Year is accepted only if it matches:

```regex
^(19|20)\d{2}$
```

Product principle: prefer an incomplete but honest card over a detailed wrong card.

## Apple Intelligence Product Limitations

FoundationModels / Apple Intelligence in this app runs on-device through `SystemLanguageModel`. It does not search the internet.

Do not treat it as a reliable database for:

- movie directors;
- book authors;
- release years;
- publication dates;
- album metadata;
- cultural facts not present in the transcript.

Current product rule:

- The app should extract title, category, emotion, memory, and echo line.
- `creator` and `year` are optional bonuses.
- `creator` and `year` should remain empty unless clearly present, explicitly mentioned, or extremely certain.

Example:

```text
I watched the film Bohemian Rhapsody.
```

Preferred MVP card:

```text
Title: Bohemian Rhapsody
Category: Film
Creator: nil
Year: nil
Memory: I watched the film Bohemian Rhapsody.
```

Do not force:

```text
Creator: Bryan Singer
Year: 2018
```

unless a reliable data source is added later.

Future metadata options, not V1:

1. user fills metadata manually;
2. local curated knowledge base;
3. external API such as TMDB, OpenLibrary, MusicBrainz, Wikidata.

V1 remains offline-first and avoids third-party APIs.

## Info.plist Requirements

The app needs privacy strings for microphone and speech recognition.

Expected keys:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Echo uses the microphone to capture your spoken memory.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Echo uses speech recognition to turn your spoken memory into text.</string>
```

## Engineering Rules

- Keep changes scoped to the requested step.
- Prefer technical stability over visual polish.
- Keep UI replaceable by the design team.
- Do not introduce backend, login, social feed, external images, posters, covers, or third-party cultural APIs in V1.
- Maintain offline-first behavior.
- Preserve explicit Type mode even after Speech improvements.
- Preserve manual review/edit fallback even after AI improvements.
- Use SwiftData, not a custom JSON store.
- Use `EchoMemoryDraft` for temporary generated/review data.
- Create `EchoMemory` only when saving.
- Use `EchoMemoryPersistenceService` for insert, update, soft delete, restore, permanent delete, and purge.
- Use Apple documentation search before implementing newer Apple frameworks like Speech, FoundationModels, App Intents, or Liquid Glass.
- Do not directly edit `.pbxproj` files.
- Use `BuildProject` after significant changes.

## Current Build Status

Recent builds succeeded after these changes:

- Speech migration to `SpeechAnalyzer` + `DictationTranscriber`.
- Microphone capture migration to `CaptureInputSequenceProvider`.
- FoundationModels integration.
- AI anti-hallucination recalibration.
- Speech context from saved Echo titles and creators.

## Manual Test Status

The app has been tested manually by the user and generally works well.

Working flows include:

- speech capture;
- text capture;
- transcription;
- AI generation;
- fallback generation;
- review;
- save;
- collection display;
- detail;
- edit;
- delete;
- undo delete;
- recently deleted;
- restore;
- permanent delete.

## Recommended Next Steps

Highest-value next technical work:

1. Add targeted tests for `AIExtractionService` fallback and post-processing.
2. Add targeted tests for `SpeechRecognitionContextProvider` deduplication and 100-term cap.
3. Add targeted tests for `EchoMemoryLinkService` local scoring, rebuild, cleanup, and model fallback behavior.
4. Improve user-facing error states for Speech and Apple Intelligence availability.
5. Add a design-facing graph / constellation view once the visual direction is ready.
6. Add App Intent / Siri shortcut if time permits.
7. Leave final visual polish to design integration.

Potential next prompts:

```text
Ajoute des tests ciblés pour AIExtractionService et SpeechRecognitionContextProvider.
```

```text
Améliore les messages d'erreur Apple Intelligence / Speech sans toucher au design final.
```

```text
Prépare l'App Intent Siri pour ouvrir CaptureView.
```

```text
Ajoute un indicateur discret quand FoundationModels fallback sur l'heuristique locale.
```

## Do Not Do Without Confirmation

- Do not add TMDB, IMDb, OpenLibrary, MusicBrainz, Wikidata, or any external API.
- Do not add backend.
- Do not add login.
- Do not add CloudKit.
- Do not add posters, covers, or user images.
- Do not redesign the whole UI.
- Do not revert to `AVAudioEngine.installTap`.
- Do not replace SwiftData with JSON.
- Do not make App Intents or Siri required for the core MVP flow.
