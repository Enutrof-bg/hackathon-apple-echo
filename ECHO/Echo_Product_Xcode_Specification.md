# Echo - Product & Xcode Implementation Specification

**Version:** MVP hackathon, updated collection/discovery concept  
**Target:** iOS app built with SwiftUI  
**Document purpose:** This document is meant to be given to Xcode / an AI coding agent as a detailed product and implementation brief.  
**Interface language:** English  
**Product language in this document:** French, with exact UI strings in English.

---

## 0. Executive summary

Echo is an iOS app for building a personal cultural collection.

The app lets the user collect two kinds of cultural cards:

1. **Open Cards** - works the user wants to discover later: a film to watch, a book to read, an album to listen to, an exhibition to visit, a game to play, a performance to see. These cards are saved in the gallery but remain visually muted, greyed, and incomplete.
2. **Echo Cards** - works the user has already experienced. These cards are revealed and completed with the user's memory, emotion, and a short poetic `echoLine`.

The app is not a social network, not a simple watchlist, and not a database of posters. Echo treats each cultural work as a small collectible object. Some cards remember. Some cards wait.

**Core promise:**

```text
Collect what stayed. Keep what calls.
```

**Guiding product sentence:**

```text
Echo does not collect posters. Echo collects what remains.
```

---

## 1. Product vision

Echo turns cultural life into a living collection.

The user can save:

- works they already experienced;
- works they want to discover;
- emotions connected to those works;
- personal memories;
- links between works that resonate with each other.

The app should feel like a calm, playful, refined collection system. The pleasure of use comes from collecting, revealing, completing, and connecting cards.

The product should be understandable in less than 20 seconds:

```text
Gallery = my collection.
Capture = add or reveal a card.
Discover = suggestions I can collect.
```

---

## 2. Core product principles

### 2.1 The card is the product

Every feature should support the idea that the user is building a collection of cards.

A card is not just a row in a list. It is a small object with:

- a fixed square format;
- a clear status;
- a category mark;
- an emotion accent;
- a concise identity;
- a place in the user's gallery.

### 2.2 Two card states only for MVP

Do not overcomplicate the state system.

Use only:

```text
Open Card = to discover / not yet experienced / greyed / incomplete.
Echo Card = experienced / revealed / completed / emotional.
```

Avoid extra states such as archived, skipped, in progress, abandoned, liked, rated, etc. for the MVP.

### 2.3 The gallery contains everything

The gallery is not only for finished memories. It contains all collected cards:

- open cards;
- revealed cards.

Open and revealed cards must share the same square format. The user should feel that all cards belong to one coherent collection.

### 2.4 The feed is not social

The feed is an inspiration/discovery space. It proposes new Open Cards the user may add to the gallery.

It should not look like TikTok, Instagram, Twitter/X, or a social content feed. It should look like a calm stack of collectible cards.

Recommended UI label:

```text
Discover
```

Internal naming can still use `DiscoverView` or `FeedView`, but the user-facing tab should preferably be `Discover`.

### 2.5 Recommendations must be explainable

Every suggested card should include a short explanation:

```text
Because you collect calm films.
Same emotion, new category.
A gentle step outside your comfort zone.
A surprise from a category you rarely explore.
```

The user should understand why the app proposes a card.

### 2.6 Playful, not gamified

The app should feel playful through:

- collecting cards;
- grey cards becoming revealed cards;
- subtle haptics;
- card flip/reveal animations;
- visual links between cards;
- a satisfying gallery grid.

Do not add heavy gamification in the MVP:

- no points;
- no streaks;
- no levels;
- no public achievements;
- no competitive mechanics.

The collection itself is the reward.

---

## 3. Product vocabulary

Use this vocabulary consistently in code, UI, and product thinking.

### 3.1 Echo

An `Echo` is the personal trace that remains after the user experiences a work.

It includes:

- memory;
- emotion;
- echo line;
- date revealed;
- optional original transcript.

### 3.2 Card

A `Card` is the collectible representation of a cultural work.

All cards are square. All cards are part of the same visual system.

### 3.3 Open Card

An Open Card is a card for a work the user wants to discover.

It is saved in the gallery but remains incomplete.

It usually contains:

- title;
- creator if known;
- category;
- suggested emotion if relevant;
- reason why it was added or recommended;
- status `open`.

It does not contain:

- personal memory;
- confirmed emotion;
- echo line.

### 3.4 Echo Card / Revealed Card

An Echo Card is a card for a work the user has experienced.

It contains:

- title;
- creator;
- category;
- confirmed emotion;
- personal memory;
- echo line;
- reveal date;
- status `revealed`.

### 3.5 Reveal

To reveal a card means to transform an Open Card into an Echo Card.

Example:

```text
The user saved "Stalker" as a film to discover.
After watching it, they open the card and tap "Reveal with an Echo".
They record or type their memory.
The app completes the card.
```

### 3.6 Gallery

The Gallery is the user's complete collection. It contains both Open Cards and Echo Cards.

### 3.7 Discover

Discover is the recommendation/inspiration feed. It proposes Open Cards to collect.

### 3.8 Nourishment mode

The user can decide how they want the app to feed them culturally.

Recommended modes:

```text
Close - stay close to my current taste.
Bridge - expand gently from my collection.
Surprise - take me outside my comfort zone.
Emotion - follow a feeling.
```

---

## 4. MVP scope

### 4.1 Must-have MVP

The MVP must include:

- local storage of cards;
- gallery with square cards;
- two card statuses: open and revealed;
- capture screen with audio and text input;
- ability to add a work as an Open Card;
- ability to add a work directly as an Echo Card;
- ability to reveal an Open Card later;
- detail view for every card;
- edit and delete;
- simple Discover feed using local seed data or rule-based suggestions;
- recommendation explanation text;
- category graphic system without color;
- emotion color system;
- clean fallback if speech or AI is unavailable.

### 4.2 Nice-to-have MVP

Only implement if time allows:

- photo input as a capture source;
- App Intent / Siri shortcut to open capture;
- subtle Liquid Glass for the capture control;
- animated card flip on reveal;
- local graph of related cards;
- search and filters;
- small onboarding of 2 screens maximum.

### 4.3 Out of scope for MVP

Do not implement:

- user accounts;
- backend;
- cloud sync;
- social features;
- public sharing;
- comments;
- likes;
- ratings;
- external APIs such as IMDb, Spotify, TMDB, Goodreads, Google Arts;
- imported posters/covers;
- user-uploaded images inside cards;
- complex recommendation engine;
- heavy gamification.

---

## 5. App structure

Use a three-tab structure.

```text
Gallery | Capture | Discover
```

### 5.1 Gallery tab

Purpose: show the user's complete cultural collection.

Contains:

- open cards;
- revealed cards;
- filters;
- search if fast to implement.

### 5.2 Capture tab

Purpose: main action screen.

Allows the user to:

- create an Echo Card from a lived memory;
- create an Open Card from a work they want to discover;
- reveal an existing Open Card.

### 5.3 Discover tab

Purpose: feed of suggested cards.

Allows the user to:

- browse suggested works;
- understand why a work is suggested;
- choose a nourishment mode;
- add a suggested work to the gallery as an Open Card.

---

## 6. Main user flows

## 6.1 Flow A - Add a work to discover

Use case:

The user hears about a work and wants to keep it for later.

Steps:

1. User opens `Capture`.
2. User taps `Add to Discover` or chooses text input.
3. User enters or says: `I want to watch Paris, Texas`.
4. App extracts basic information:
   - title: `Paris, Texas`
   - category: `Film`
   - creator: `Wim Wenders` if confidently known, otherwise empty.
5. App shows a review card in open/grey state.
6. User taps `Add Open Card`.
7. Card appears in Gallery as greyed square card.

Expected UI strings:

```text
Add an Open Card
Keep a work for later.
```

```text
Add Open Card
```

Data result:

```text
status = open
memory = nil
echoLine = nil
confirmedEmotion = nil
suggestedEmotion = optional
```

---

## 6.2 Flow B - Capture a lived work directly

Use case:

The user just watched/read/listened to something and wants to record what it left in them.

Steps:

1. User opens `Capture`.
2. User taps main capture button.
3. User speaks naturally:

```text
I want to remember Spirited Away. I watched it with my sister when we were kids. It made me feel safe and amazed.
```

4. App transcribes speech.
5. App uses local AI/structured extraction if available.
6. App creates a draft Echo Card:
   - title;
   - creator;
   - category;
   - emotion;
   - memory;
   - echo line.
7. User reviews.
8. User taps `Save Echo`.
9. Card appears in Gallery as revealed.

Expected UI strings:

```text
Capture an Echo
Speak about what stayed with you.
```

```text
Save Echo
```

---

## 6.3 Flow C - Reveal an Open Card

Use case:

The user saved a work to discover, then experienced it later.

Steps:

1. User opens Gallery.
2. User taps a grey Open Card.
3. Detail view opens.
4. Main CTA is `Reveal with an Echo`.
5. User records or types their memory.
6. App generates completed fields:
   - confirmed emotion;
   - personal memory;
   - echo line.
7. User reviews.
8. User taps `Reveal Card`.
9. Card visually changes from grey/open to revealed/colored.
10. Gallery updates immediately.

Expected UI strings:

```text
Reveal with an Echo
```

```text
This card is waiting to be lived.
```

```text
Reveal Card
```

Animation:

- subtle card flip or fade from grey to active;
- light haptic feedback;
- no confetti by default.

---

## 6.4 Flow D - Add from Discover feed

Use case:

The app proposes works to discover.

Steps:

1. User opens Discover.
2. User chooses a nourishment mode:
   - Close;
   - Bridge;
   - Surprise;
   - Emotion.
3. Feed displays square grey suggestion cards.
4. Each card explains why it is proposed.
5. User taps `Add to Gallery`.
6. Card is saved as an Open Card.
7. The button changes to `Added`.
8. Card appears in Gallery.

Expected UI strings:

```text
Why this card?
Because you collect calm films.
```

```text
Add to Gallery
```

```text
Added
```

---

## 6.5 Flow E - Edit a card

Use case:

The AI extracted something wrong or the user wants to refine it.

Steps:

1. User opens a card detail view.
2. User taps `Edit`.
3. User edits available fields.
4. User taps `Save Changes`.

For Open Cards, editable fields:

- title;
- creator;
- category;
- suggested emotion;
- note;
- recommendation reason.

For Echo Cards, editable fields:

- title;
- creator;
- category;
- confirmed emotion;
- memory;
- echo line;
- year.

---

## 7. Screen-by-screen specification

## 7.1 Main tab container

Recommended SwiftUI structure:

```swift
struct RootTabView: View {
    var body: some View {
        TabView {
            GalleryView()
                .tabItem { Label("Gallery", systemImage: "square.grid.2x2") }

            CaptureHomeView()
                .tabItem { Label("Capture", systemImage: "waveform") }

            DiscoverView()
                .tabItem { Label("Discover", systemImage: "sparkles") }
        }
    }
}
```

Keep tab labels short.

---

## 7.2 GalleryView

Purpose:

Show all cards in the collection.

Layout:

- large title: `Gallery`;
- optional subtitle: `Your cultural collection`;
- segmented filter row:
  - `All`;
  - `Open`;
  - `Revealed`;
- optional filter chips for emotion/category;
- 2-column grid of square cards;
- floating or top-right `+` button optional.

Empty state:

```text
No cards yet.
Collect a work you lived or one you want to discover.
```

Empty state CTAs:

```text
Capture an Echo
Explore Discover
```

Card layout:

- square;
- 2 columns;
- spacing: 12-16 pt;
- outer margins: 20 pt;
- no images;
- same component for open/revealed status.

Open cards visual state:

- greyed but desirable;
- lower contrast;
- dashed border or soft dotted frame;
- no strong emotion color;
- label: `Open` or `To discover`.

Revealed cards visual state:

- active text contrast;
- subtle emotion accent color;
- solid border;
- label: `Echo` or emotion name.

Tap behavior:

- open detail view.

Long press behavior, optional:

- quick actions:
  - `Reveal` for open card;
  - `Edit`;
  - `Delete`.

---

## 7.3 CaptureHomeView

Purpose:

Central action screen. It should feel obvious and frictionless.

Layout:

- app title: `Echo`;
- short baseline:

```text
Collect what stayed. Keep what calls.
```

- central capture control;
- three minimal input options:
  - microphone;
  - text;
  - camera/photo optional;
- two creation paths:
  - `Capture an Echo` for a lived work;
  - `Add Open Card` for a work to discover.

Suggested UI hierarchy:

```text
Echo
Collect what stayed. Keep what calls.

[large circular capture button]
Capture an Echo

[Text] [Voice] [Photo]

Add Open Card
```

The primary visual focus should be the capture control.

Do not show long explanatory text.

### Voice capture states

State 1:

```text
Tap to record
```

State 2:

```text
Listening...
```

State 3:

```text
Review transcription
```

State 4:

```text
Create Card
```

### Text input fallback

If speech is unavailable or the user chooses text:

```text
Type your memory instead.
```

For Open Card:

```text
Type a work you want to discover.
```

### Photo input optional

If implemented, photo input should not add an image to the card.

Photo can only be used as an input source to help create the card.

Examples:

- photo of a book cover;
- photo of a museum label;
- photo of a concert poster.

The final card remains text-only.

---

## 7.4 DiscoverView

Purpose:

Show suggested Open Cards to collect.

User-facing tab label:

```text
Discover
```

Layout:

- title: `Discover`;
- subtitle: optional and short:

```text
Choose how you want to be fed.
```

- nourishment mode selector:
  - `Close`;
  - `Bridge`;
  - `Surprise`;
  - `Emotion`.
- vertical feed of square cards;
- each card is grey/open by default;
- each card has a reason;
- CTA: `Add to Gallery`.

Suggested feed card fields:

- category;
- title;
- creator;
- suggested emotion;
- reason;
- CTA.

Example card:

```text
Film
Paris, Texas
Wim Wenders
Suggested feeling: Melancholy

Because you collect quiet, nostalgic films.

Add to Gallery
```

Discover feed should avoid feeling infinite or addictive. A short curated stack is enough.

Recommended MVP behavior:

- show 8-12 suggestions;
- allow pull-to-refresh or `New cards` button;
- generate from local seed data;
- exclude cards already in the gallery.

---

## 7.5 CardDetailView

Purpose:

Show the full information for a card.

For Open Card:

- large square card preview;
- status: `Open Card`;
- title;
- creator;
- category;
- suggested emotion if available;
- reason/note;
- CTA: `Reveal with an Echo`;
- secondary actions: `Edit`, `Delete`.

Open Card copy:

```text
This card is waiting to be lived.
```

For Echo Card:

- large square card preview;
- status: `Echo Card`;
- title;
- creator;
- category;
- confirmed emotion;
- date revealed;
- memory;
- echo line;
- related cards section;
- actions: `Edit`, `Delete`.

Echo Card copy:

```text
What stayed
```

For related cards:

```text
Related echoes
```

---

## 7.6 ReviewCardView

Purpose:

Let the user check a generated card before saving.

Use the same square card component.

For Open Card draft:

Buttons:

```text
Add Open Card
Edit
Discard
```

For Echo Card draft:

Buttons:

```text
Save Echo
Edit
Discard
```

For revealing an existing Open Card:

Buttons:

```text
Reveal Card
Edit
Cancel
```

---

## 8. Card design system

## 8.1 Format

All cards must be square.

Use the same component everywhere:

- Gallery grid cards;
- Discover feed cards;
- Review cards;
- Detail preview cards.

The only difference is size.

Recommended dimensions:

- Gallery grid card: computed width, height equal to width.
- Feed card: width = screen width minus 40 pt, height equal to width.
- Detail card: width = screen width minus 40 pt, height equal to width.

## 8.2 Card internal structure

Each card should have stable internal zones.

```text
Top left: category mark + category label
Top right: status marker / bookmark / open indicator

Center: title
Below title: creator

Bottom left: emotion / suggested emotion
Bottom right: small category pattern or card index optional
```

For revealed cards:

```text
Category
Title
Creator
Emotion
Echo line
```

For open cards:

```text
Category
Title
Creator
To discover
Reason or suggested emotion
```

Do not overload the card. Long memory text belongs in detail view.

## 8.3 Open Card visual style

Open Cards should feel like cards waiting to be revealed, not disabled UI.

Visual rules:

- background: off-white / light grey;
- text: medium grey;
- border: dashed or dotted;
- no strong emotion fill;
- optional small lock/open-circle symbol;
- category mark visible but muted;
- status label: `Open`.

Avoid:

- making cards look broken;
- making cards too low contrast to read;
- using disabled opacity below 0.55;
- hiding essential information.

## 8.4 Echo Card visual style

Revealed cards should feel complete and alive.

Visual rules:

- background: off-white or white;
- text: high contrast;
- border: solid;
- subtle emotion accent;
- category mark clear;
- status label: emotion or `Echo`.

## 8.5 Emotion color system

Color is reserved for emotion.

Do not use color as the main category identifier.

Recommended emotion colors as asset names:

```swift
enum EchoEmotion: String, Codable, CaseIterable, Identifiable {
    case nostalgia
    case joy
    case wonder
    case melancholy
    case calm
    case shock
    case love
    case curiosity

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nostalgia: return "Nostalgia"
        case .joy: return "Joy"
        case .wonder: return "Wonder"
        case .melancholy: return "Melancholy"
        case .calm: return "Calm"
        case .shock: return "Shock"
        case .love: return "Love"
        case .curiosity: return "Curiosity"
        }
    }

    var colorAssetName: String {
        switch self {
        case .nostalgia: return "EmotionNostalgia"
        case .joy: return "EmotionJoy"
        case .wonder: return "EmotionWonder"
        case .melancholy: return "EmotionMelancholy"
        case .calm: return "EmotionCalm"
        case .shock: return "EmotionShock"
        case .love: return "EmotionLove"
        case .curiosity: return "EmotionCuriosity"
        }
    }
}
```

Suggested color direction:

- Nostalgia: warm faded amber / sepia.
- Joy: soft yellow.
- Wonder: violet / blue glow.
- Melancholy: muted blue.
- Calm: pale green / sage.
- Shock: sharp red / coral accent.
- Love: muted pink.
- Curiosity: electric but restrained cyan.

Use colors subtly:

- thin border;
- tiny dot;
- underline;
- corner accent;
- small halo;
- not a full saturated card background.

For Open Cards, show suggested emotion in grey, not full color. Full emotion color is unlocked when revealed.

## 8.6 Category graphic system without color

Category must be readable without using color.

Use a combination of:

- SF Symbol;
- small abstract mark;
- border treatment;
- pattern line.

Recommended category system:

```swift
enum EchoCategory: String, Codable, CaseIterable, Identifiable {
    case film
    case book
    case music
    case painting
    case sculpture
    case videoGame
    case architecture
    case performance
    case place
    case object
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .film: return "Film"
        case .book: return "Book"
        case .music: return "Music"
        case .painting: return "Painting"
        case .sculpture: return "Sculpture"
        case .videoGame: return "Video Game"
        case .architecture: return "Architecture"
        case .performance: return "Performance"
        case .place: return "Place"
        case .object: return "Object"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .film: return "film"
        case .book: return "book.closed"
        case .music: return "music.note"
        case .painting: return "paintpalette"
        case .sculpture: return "cube"
        case .videoGame: return "gamecontroller"
        case .architecture: return "building.columns"
        case .performance: return "theatermasks"
        case .place: return "mappin.and.ellipse"
        case .object: return "shippingbox"
        case .other: return "sparkle"
        }
    }

    var patternName: String {
        switch self {
        case .film: return "horizontal-strips"
        case .book: return "vertical-spine"
        case .music: return "wave-lines"
        case .painting: return "frame-corners"
        case .sculpture: return "volume-lines"
        case .videoGame: return "pixel-grid"
        case .architecture: return "plan-grid"
        case .performance: return "spotlight-arc"
        case .place: return "map-contour"
        case .object: return "box-outline"
        case .other: return "single-spark"
        }
    }
}
```

Graphic direction by category:

- Film: abstract film strip, two horizontal bars, frame corners.
- Book: vertical spine line, double-column mark.
- Music: waveform or staff-like lines.
- Painting: corner frame marks, light canvas grain.
- Sculpture: volume/cube line mark.
- Video Game: tiny pixel grid or D-pad abstraction.
- Architecture: plan grid, column line, structural axis.
- Performance: spotlight arc, stage line, curtain-like vertical strokes.
- Place: contour line, pin abstraction, map fold.
- Object: simple box outline.
- Other: small spark or neutral mark.

Keep this system black/grey. Emotion uses color; category uses form.

---

## 9. Data model

Use SwiftData if possible. JSON local storage is acceptable if it is faster.

Recommended SwiftData model:

```swift
import Foundation
import SwiftData

@Model
final class EchoCard {
    @Attribute(.unique) var id: UUID

    var title: String
    var creator: String?
    var year: String?

    var categoryRawValue: String
    var statusRawValue: String

    // For revealed cards, this is the confirmed emotion.
    var emotionRawValue: String?

    // For open cards, this is an anticipated or suggested emotion.
    var suggestedEmotionRawValue: String?

    // Personal content. Usually nil for open cards.
    var memory: String?
    var echoLine: String?
    var originalTranscript: String?

    // Discovery / recommendation content.
    var discoveryReason: String?
    var userNote: String?
    var recommendationModeRawValue: String?
    var sourceCardID: UUID?

    // Links and tags.
    var tags: [String]
    var relatedCardIDs: [UUID]

    var createdAt: Date
    var updatedAt: Date
    var revealedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        creator: String? = nil,
        year: String? = nil,
        category: EchoCategory,
        status: EchoCardStatus,
        emotion: EchoEmotion? = nil,
        suggestedEmotion: EchoEmotion? = nil,
        memory: String? = nil,
        echoLine: String? = nil,
        originalTranscript: String? = nil,
        discoveryReason: String? = nil,
        userNote: String? = nil,
        recommendationMode: RecommendationMode? = nil,
        sourceCardID: UUID? = nil,
        tags: [String] = [],
        relatedCardIDs: [UUID] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        revealedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.creator = creator
        self.year = year
        self.categoryRawValue = category.rawValue
        self.statusRawValue = status.rawValue
        self.emotionRawValue = emotion?.rawValue
        self.suggestedEmotionRawValue = suggestedEmotion?.rawValue
        self.memory = memory
        self.echoLine = echoLine
        self.originalTranscript = originalTranscript
        self.discoveryReason = discoveryReason
        self.userNote = userNote
        self.recommendationModeRawValue = recommendationMode?.rawValue
        self.sourceCardID = sourceCardID
        self.tags = tags
        self.relatedCardIDs = relatedCardIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.revealedAt = revealedAt
    }
}
```

Computed helpers can be added in an extension:

```swift
extension EchoCard {
    var category: EchoCategory {
        get { EchoCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    var status: EchoCardStatus {
        get { EchoCardStatus(rawValue: statusRawValue) ?? .open }
        set { statusRawValue = newValue.rawValue }
    }

    var emotion: EchoEmotion? {
        get { emotionRawValue.flatMap(EchoEmotion.init(rawValue:)) }
        set { emotionRawValue = newValue?.rawValue }
    }

    var suggestedEmotion: EchoEmotion? {
        get { suggestedEmotionRawValue.flatMap(EchoEmotion.init(rawValue:)) }
        set { suggestedEmotionRawValue = newValue?.rawValue }
    }

    var isOpen: Bool { status == .open }
    var isRevealed: Bool { status == .revealed }
}
```

Card status enum:

```swift
enum EchoCardStatus: String, Codable, CaseIterable, Identifiable {
    case open
    case revealed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .open: return "Open"
        case .revealed: return "Echo"
        }
    }
}
```

Recommendation mode enum:

```swift
enum RecommendationMode: String, Codable, CaseIterable, Identifiable {
    case close
    case bridge
    case surprise
    case emotion

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .close: return "Close"
        case .bridge: return "Bridge"
        case .surprise: return "Surprise"
        case .emotion: return "Emotion"
        }
    }

    var explanation: String {
        switch self {
        case .close: return "Stay close to your current collection."
        case .bridge: return "Expand gently from what you already love."
        case .surprise: return "Step outside your comfort zone."
        case .emotion: return "Follow a feeling across categories."
        }
    }
}
```

---

## 10. Draft models for AI/service output

The app should generate drafts before saving final cards.

```swift
struct EchoCardDraft: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var creator: String?
    var year: String?
    var category: EchoCategory
    var status: EchoCardStatus
    var emotion: EchoEmotion?
    var suggestedEmotion: EchoEmotion?
    var memory: String?
    var echoLine: String?
    var originalTranscript: String?
    var discoveryReason: String?
    var tags: [String]
}
```

Use drafts in:

- ReviewCardView;
- manual entry fallback;
- AI generation result;
- recommendation cards before they are saved.

---

## 11. Local seed catalog

Because the MVP should not depend on external APIs, Discover should use a bundled local catalog.

Create a JSON file in the app bundle:

```text
SeedWorks.json
```

Recommended fields:

```swift
struct SeedWork: Codable, Identifiable {
    var id: String
    var title: String
    var creator: String?
    var year: String?
    var category: EchoCategory
    var suggestedEmotions: [EchoEmotion]
    var tags: [String]
    var comfortLevel: Int // 1 = accessible, 5 = challenging
    var canonicalReason: String
}
```

Sample JSON:

```json
[
  {
    "id": "film-paris-texas",
    "title": "Paris, Texas",
    "creator": "Wim Wenders",
    "year": "1984",
    "category": "film",
    "suggestedEmotions": ["melancholy", "nostalgia"],
    "tags": ["road", "family", "silence", "memory"],
    "comfortLevel": 3,
    "canonicalReason": "A quiet film about distance, memory, and returning."
  },
  {
    "id": "book-invisible-cities",
    "title": "Invisible Cities",
    "creator": "Italo Calvino",
    "year": "1972",
    "category": "book",
    "suggestedEmotions": ["wonder", "curiosity"],
    "tags": ["cities", "dream", "architecture", "imagination"],
    "comfortLevel": 4,
    "canonicalReason": "A poetic bridge between literature and imagined architecture."
  },
  {
    "id": "music-music-for-airports",
    "title": "Music for Airports",
    "creator": "Brian Eno",
    "year": "1978",
    "category": "music",
    "suggestedEmotions": ["calm", "curiosity"],
    "tags": ["ambient", "space", "slow", "minimal"],
    "comfortLevel": 2,
    "canonicalReason": "A calm entry point into ambient listening."
  }
]
```

For a hackathon, start with 30-60 seed works across categories.

---

## 12. Recommendation logic

The Discover feed does not need a complex machine learning engine.

Use a local, explainable scoring system.

### 12.1 User profile

Build a lightweight profile from saved cards.

Track:

- category counts;
- confirmed emotion counts;
- suggested emotion counts from open cards;
- tags from revealed and open cards;
- recently added categories;
- underrepresented categories.

Example:

```swift
struct UserTasteProfile {
    var categoryCounts: [EchoCategory: Int]
    var emotionCounts: [EchoEmotion: Int]
    var tagCounts: [String: Int]
    var recentCategories: [EchoCategory]
    var underrepresentedCategories: [EchoCategory]
}
```

### 12.2 Scoring by mode

#### Close mode

Goal: stay close to current taste.

Boost if:

- same dominant emotion;
- same frequent category;
- overlapping tags;
- comfort level 1-3.

Example explanation:

```text
Because you collect calm music and quiet films.
```

#### Bridge mode

Goal: gently expand.

Boost if:

- same emotion but different category;
- shared tags but new medium;
- category adjacent to user's habits.

Example explanation:

```text
Same feeling, another language.
```

#### Surprise mode

Goal: leave comfort zone.

Boost if:

- category is underrepresented;
- emotion is rare in user's collection;
- comfort level 3-5;
- low tag overlap but one meaningful bridge remains.

Example explanation:

```text
A card outside your usual paths.
```

#### Emotion mode

Goal: follow one selected feeling.

User chooses an emotion, or the app picks a dominant emotion.

Boost if:

- seed work includes selected emotion;
- category diversity is high.

Example explanation:

```text
A different way to follow melancholy.
```

### 12.3 Simple scoring pseudocode

```swift
func score(seed: SeedWork, profile: UserTasteProfile, mode: RecommendationMode, selectedEmotion: EchoEmotion?) -> Double {
    var score = 0.0

    let emotionOverlap = seed.suggestedEmotions.reduce(0) { partial, emotion in
        partial + (profile.emotionCounts[emotion] ?? 0)
    }

    let categoryCount = profile.categoryCounts[seed.category] ?? 0
    let tagOverlap = seed.tags.reduce(0) { partial, tag in
        partial + (profile.tagCounts[tag] ?? 0)
    }

    switch mode {
    case .close:
        score += Double(emotionOverlap) * 3.0
        score += Double(categoryCount) * 2.0
        score += Double(tagOverlap) * 1.5
        score += max(0, Double(4 - seed.comfortLevel))

    case .bridge:
        score += Double(emotionOverlap) * 3.0
        score += seed.categoryIsUnderrepresented(in: profile) ? 2.0 : 0.0
        score += Double(tagOverlap) * 1.0
        score += seed.comfortLevel <= 4 ? 1.0 : 0.0

    case .surprise:
        score += seed.categoryIsUnderrepresented(in: profile) ? 4.0 : 0.0
        score += Double(max(0, 3 - tagOverlap))
        score += Double(seed.comfortLevel) * 0.7
        score += emotionOverlap > 0 ? 1.0 : 0.0

    case .emotion:
        if let selectedEmotion {
            score += seed.suggestedEmotions.contains(selectedEmotion) ? 6.0 : 0.0
        } else {
            score += Double(emotionOverlap) * 2.0
        }
        score += seed.categoryIsUnderrepresented(in: profile) ? 1.5 : 0.0
    }

    return score
}
```

### 12.4 Recommendation explanation templates

Generate explanations with templates rather than relying on AI every time.

```swift
func explanation(for seed: SeedWork, mode: RecommendationMode, profile: UserTasteProfile) -> String {
    switch mode {
    case .close:
        return "Because it stays close to your recent echoes."
    case .bridge:
        return "Same feeling, a new cultural form."
    case .surprise:
        return "A card outside your usual paths."
    case .emotion:
        if let emotion = seed.suggestedEmotions.first {
            return "A new way to follow \(emotion.displayName.lowercased())."
        } else {
            return seed.canonicalReason
        }
    }
}
```

Prefer specific explanations when possible:

- `Because you collect nostalgic films.`
- `Because calm appears often in your gallery.`
- `Because architecture is still rare in your collection.`
- `Same emotion, new category.`

---

## 13. Links between cards

Echo should make the user's collection feel connected.

For MVP, links can be computed locally.

Two cards are related if they share:

- emotion;
- category;
- creator;
- tags;
- nearby date;
- semantic memory similarity if AI available.

### 13.1 Link types

```swift
enum EchoLinkReason: String, Codable, CaseIterable {
    case sameEmotion
    case sameCategory
    case sameCreator
    case sharedTag
    case bridgeCategory
    case contrast
}
```

### 13.2 Related card model

```swift
struct RelatedCardSuggestion: Identifiable {
    var id: UUID { card.id }
    var card: EchoCard
    var reason: EchoLinkReason
    var explanation: String
    var score: Double
}
```

### 13.3 Detail view copy examples

```text
Same emotion
Both cards carry melancholy.
```

```text
Same feeling, another form
A film and an album connected by calm.
```

```text
A useful contrast
This card answers nostalgia with curiosity.
```

For the MVP, show up to 3 related cards in the detail view.

---

## 14. AI behavior

The app can use Apple Intelligence / local Foundation Models when available, but must not break if unavailable.

Design the AI layer as a replaceable service.

```swift
protocol AIExtractionServicing {
    func createEchoDraft(from transcript: String) async throws -> EchoCardDraft
    func createOpenDraft(from input: String) async throws -> EchoCardDraft
    func revealDraft(existingCard: EchoCard, transcript: String) async throws -> EchoCardDraft
}
```

If AI is unavailable, use manual forms and simple parsing.

## 14.1 Prompt for lived Echo Card

Input:

- free-form memory text;
- allowed categories;
- allowed emotions.

Prompt:

```text
You are helping create a personal cultural memory card for an app called Echo.
The user speaks freely about a cultural work they experienced.
Extract a structured card.

Rules:
- Preserve the user's personal memory.
- Do not invent the creator or year if uncertain.
- Choose exactly one category from the allowed category list.
- Choose exactly one dominant emotion from the allowed emotion list.
- Write a short poetic echo line, maximum 18 words.
- The echo line must feel personal and emotional, not promotional.
- Output only the requested structured fields.

Allowed categories:
Film, Book, Music, Painting, Sculpture, Video Game, Architecture, Performance, Place, Object, Other.

Allowed emotions:
Nostalgia, Joy, Wonder, Melancholy, Calm, Shock, Love, Curiosity.

Required output:
- title
- creator
- year
- category
- emotion
- memory
- echoLine
- tags
```

## 14.2 Prompt for Open Card

Input:

- short work mention or wish;
- optional context.

Prompt:

```text
You are helping create an Open Card for Echo.
An Open Card is a cultural work the user wants to discover later.
Extract only reliable information.

Rules:
- Do not invent creator or year if uncertain.
- Choose one category from the allowed list.
- If a likely emotion is implied, suggest one emotion; otherwise leave it empty.
- Create a short reason that explains why the user saved it, based only on the input.
- Do not write a personal memory.
- Do not write an echo line.

Required output:
- title
- creator
- year
- category
- suggestedEmotion
- discoveryReason
- tags
```

## 14.3 Prompt for revealing an Open Card

Input:

- existing card fields;
- user's new memory transcript.

Prompt:

```text
You are completing an existing Open Card in Echo.
The user has now experienced the work.
Use the existing title, creator, year, and category unless the user clearly corrects them.
Extract the personal memory, choose the dominant emotion, and write an echo line.

Rules:
- Preserve the user's personal memory.
- Keep the work identity stable.
- Do not overwrite reliable existing fields unless correction is explicit.
- Choose exactly one emotion.
- Write a short poetic echo line, maximum 18 words.

Required output:
- title
- creator
- year
- category
- emotion
- memory
- echoLine
- tags
```

---

## 15. Fallback behavior

The app must remain usable offline and without AI.

### 15.1 Speech unavailable

Show:

```text
Type your memory instead.
```

Allow text entry.

### 15.2 AI unavailable

Show:

```text
Echo could not shape this memory. You can still save it manually.
```

Then show a simple manual form.

### 15.3 Empty gallery

Show:

```text
No cards yet.
Collect a work you lived or one you want to discover.
```

### 15.4 No recommendation profile yet

If the user has no cards, Discover should show starter cards.

Copy:

```text
Start your collection with a few open cards.
```

### 15.5 Duplicate card

If the user tries to add a card with the same title and creator:

```text
This card is already in your gallery.
```

Actions:

- `Open Card`;
- `Add Anyway` optional.

### 15.6 Deleting a card

Confirm:

```text
Delete this card?
This cannot be undone.
```

---

## 16. Storage and offline-first

The app should work without login, backend, or internet.

Data to store locally:

- all cards;
- card status;
- created date;
- updated date;
- revealed date;
- memory;
- echo line;
- original transcript optional;
- recommendation reason;
- related card IDs;
- user settings for recommendation mode.

Recommended storage:

- SwiftData for app objects;
- bundled JSON for seed catalog;
- AppStorage for simple preferences.

```swift
@AppStorage("selectedRecommendationMode") var selectedRecommendationModeRawValue: String = RecommendationMode.bridge.rawValue
```

---

## 17. Suggested Swift file structure

Use a simple structure. Avoid overengineering.

```text
EchoApp.swift
RootTabView.swift

Models/
  EchoCard.swift
  EchoCategory.swift
  EchoEmotion.swift
  EchoCardStatus.swift
  EchoCardDraft.swift
  SeedWork.swift
  RecommendationMode.swift

Views/
  Gallery/
    GalleryView.swift
    GalleryFilterBar.swift
  Capture/
    CaptureHomeView.swift
    VoiceCaptureView.swift
    TextCaptureView.swift
    OpenCardEntryView.swift
    ReviewCardView.swift
  Discover/
    DiscoverView.swift
    NourishmentModePicker.swift
    DiscoverCardView.swift
  Card/
    EchoCardView.swift
    CategoryMarkView.swift
    EmotionAccentView.swift
    CardDetailView.swift
    EditCardView.swift
    RelatedCardsView.swift

Services/
  EchoStore.swift
  AIExtractionService.swift
  ManualExtractionService.swift
  SpeechTranscriptionService.swift
  RecommendationService.swift
  SeedCatalogService.swift
  CardLinkService.swift

Design/
  EchoDesignSystem.swift
  EchoSpacing.swift
  EchoTypography.swift
  EchoCardStyle.swift
```

For hackathon speed, some files can be merged, but the app should keep clear separation between models, views, and services.

---

## 18. Key view component - EchoCardView

This is the most important component.

It must support both Gallery and Feed sizes.

Suggested API:

```swift
struct EchoCardView: View {
    let card: EchoCardDisplayable
    let size: EchoCardSize

    var body: some View {
        // Square card with category mark, title, creator, status/emotion.
    }
}
```

Create a display protocol so `EchoCard` and `EchoCardDraft` can both render.

```swift
protocol EchoCardDisplayable {
    var title: String { get }
    var creator: String? { get }
    var category: EchoCategory { get }
    var status: EchoCardStatus { get }
    var emotion: EchoEmotion? { get }
    var suggestedEmotion: EchoEmotion? { get }
    var echoLine: String? { get }
    var discoveryReason: String? { get }
}
```

Card size enum:

```swift
enum EchoCardSize {
    case grid
    case feed
    case detail
    case review
}
```

Design behavior:

- If `status == .open`, use open card style.
- If `status == .revealed`, use revealed card style.
- If `emotion != nil`, show emotion accent.
- If only `suggestedEmotion != nil`, show it muted.

---

## 19. UI copy

All UI strings should be in English.

### Main

```text
Echo
Collect what stayed. Keep what calls.
```

### Tabs

```text
Gallery
Capture
Discover
```

### Capture

```text
Capture an Echo
Speak about what stayed with you.
Tap to record
Listening...
Stop
Create Card
Type your memory instead.
Add Open Card
Keep a work for later.
```

### Gallery

```text
Gallery
All
Open
Revealed
No cards yet.
Collect a work you lived or one you want to discover.
```

### Open Card

```text
Open Card
To discover
This card is waiting to be lived.
Reveal with an Echo
Add Open Card
```

### Echo Card

```text
Echo Card
What stayed
Save Echo
Reveal Card
```

### Discover

```text
Discover
Choose how you want to be fed.
Close
Bridge
Surprise
Emotion
Add to Gallery
Added
Why this card?
```

### Errors

```text
Echo could not shape this memory. You can still save it manually.
This card is already in your gallery.
Delete this card?
This cannot be undone.
```

---

## 20. Interaction design

### 20.1 Card reveal

When an Open Card becomes an Echo Card:

- animate border from dashed to solid;
- fade grey text to active text;
- reveal emotion color accent;
- light haptic feedback.

Do not use loud celebration UI.

### 20.2 Add to gallery from Discover

When user taps `Add to Gallery`:

- button changes to `Added`;
- small haptic feedback;
- optional mini card movement animation;
- do not navigate away automatically unless user taps the card.

### 20.3 Card tap

Tapping a card opens detail.

### 20.4 Pull to refresh Discover

Optional. If implemented, it changes suggestions from seed catalog.

---

## 21. Accessibility

Requirements:

- all cards must be readable with VoiceOver;
- do not rely on color alone;
- category is represented by text and shape/icon;
- emotion is represented by text and color;
- Open/Revealed status must be text-readable;
- buttons must have accessibility labels.

Example VoiceOver labels:

```text
Open Card. Paris, Texas. Film. Suggested emotion: Melancholy. To discover.
```

```text
Echo Card. Spirited Away. Film. Emotion: Wonder. A childhood memory wrapped in magic and safety.
```

---

## 22. Manual entry forms

Manual forms should be short and secondary.

### 22.1 Open Card manual form

Fields:

- Title, required;
- Creator, optional;
- Category, required;
- Suggested emotion, optional;
- Note, optional.

CTA:

```text
Add Open Card
```

### 22.2 Echo Card manual form

Fields:

- Title, required;
- Creator, optional;
- Category, required;
- Emotion, required;
- Memory, required;
- Echo line, optional but recommended;
- Year, optional.

CTA:

```text
Save Echo
```

---

## 23. Implementation phases

### Phase 1 - Core models and storage

Implement:

- `EchoCard` SwiftData model;
- enums;
- seed catalog loading;
- sample data preview.

Acceptance:

- app launches;
- sample cards appear;
- cards persist locally.

### Phase 2 - Card component and gallery

Implement:

- `EchoCardView` square component;
- open/revealed styles;
- category mark;
- emotion accent;
- gallery grid;
- detail view.

Acceptance:

- all cards are square;
- open cards are greyed but readable;
- revealed cards show emotion color;
- detail opens on tap.

### Phase 3 - Manual create/reveal

Implement:

- manual Open Card creation;
- manual Echo Card creation;
- reveal existing Open Card;
- edit/delete.

Acceptance:

- user can add a work to discover;
- user can add a lived work;
- user can reveal an Open Card.

### Phase 4 - Capture voice/text

Implement:

- speech permission;
- recording state;
- transcription;
- text fallback;
- ReviewCardView.

Acceptance:

- user can create a card without a long form;
- fallback works if speech fails.

### Phase 5 - AI extraction

Implement:

- `AIExtractionService` if available;
- `ManualExtractionService` fallback;
- structured draft generation.

Acceptance:

- transcript becomes a draft card;
- user can review before saving;
- AI error does not block usage.

### Phase 6 - Discover feed

Implement:

- seed catalog;
- recommendation modes;
- scoring;
- explanations;
- add to gallery.

Acceptance:

- feed proposes Open Cards;
- every card has a reason;
- user can choose `Close`, `Bridge`, `Surprise`, or `Emotion`.

### Phase 7 - Polish

Implement:

- reveal animation;
- haptics;
- Liquid Glass capture control if easy;
- App Intent if easy;
- empty states;
- accessibility labels.

---

## 24. Acceptance criteria

The MVP is successful if:

- the app is understandable in under 20 seconds;
- the card is clearly the central object;
- the user can create an Open Card;
- the user can create an Echo Card;
- the user can reveal an Open Card later;
- Gallery shows open and revealed cards together;
- Discover proposes cards with explanations;
- recommendation modes are visible and understandable;
- cards are always square;
- categories are visually distinguishable without color;
- emotions use a color system;
- no card uses external images or covers;
- local storage works;
- no login/backend is required;
- errors do not block the main flow.

---

## 25. Demo scenario

Use this demo during the hackathon.

### Step 1 - Start with an empty collection

Show Gallery empty state:

```text
No cards yet.
Collect a work you lived or one you want to discover.
```

### Step 2 - Add an Open Card

User says or types:

```text
I want to watch Paris, Texas.
```

App creates Open Card:

```text
Paris, Texas
Wim Wenders
Film
Open / To discover
```

Show it greyed in Gallery.

### Step 3 - Capture a lived Echo

User says:

```text
I want to remember Spirited Away. I watched it with my sister when we were kids. It made me feel safe and amazed.
```

App creates Echo Card:

```text
Spirited Away
Hayao Miyazaki
Film
Wonder
A childhood memory wrapped in magic and safety.
```

Show it revealed in Gallery with emotion color.

### Step 4 - Discover feed

Open Discover.

Show suggestion:

```text
Invisible Cities
Italo Calvino
Book
Suggested feeling: Wonder

Same feeling, another cultural form.
```

User taps:

```text
Add to Gallery
```

Card appears in Gallery as Open Card.

### Step 5 - Reveal an Open Card

Open `Paris, Texas`.

Tap:

```text
Reveal with an Echo
```

User enters memory.

Card transforms from grey to revealed.

### Demo closing line

```text
Echo is a collection of what we lived, and what is still waiting to become a memory.
```

---

## 26. Xcode build instruction prompt

The following prompt can be given directly to an AI coding agent in Xcode:

```text
Build an iOS SwiftUI app called Echo.

Echo is a personal cultural collection app. The user collects square cards representing cultural works. A card can be an Open Card, meaning a work the user wants to discover later, or an Echo Card, meaning a work the user has experienced and completed with a personal memory, emotion, and echo line.

Use a three-tab structure: Gallery, Capture, Discover.

Gallery shows all saved cards in a 2-column square grid. Open Cards and Echo Cards use the same square card component. Open Cards are greyed, muted, and incomplete. Echo Cards are revealed, active, and use a subtle emotion color accent. Categories must be visually identifiable without color, using SF Symbols and/or abstract black/grey marks. Emotions use color.

Capture is the main creation screen. It lets the user create a lived Echo Card from voice/text, create an Open Card for a work to discover, or reveal an existing Open Card. Voice capture should have a text fallback. AI extraction should be wrapped in a service and must gracefully fall back to manual entry if unavailable.

Discover is a calm recommendation feed. It shows square grey suggestion cards that can be added to Gallery as Open Cards. Each suggestion must explain why it is proposed. The user can choose how they want to be fed culturally: Close, Bridge, Surprise, or Emotion. For MVP, use a bundled local SeedWorks.json catalog and a simple rule-based recommendation service. Do not use external APIs.

Use SwiftData for local storage if possible. No login, no backend, no cloud sync, no social features, no external posters/covers/images. Cards are text-only.

Implement models, views, and services according to the attached specification. Prioritize: local data model, card component, gallery, manual creation/reveal, capture fallback, discover feed, then polish.
```

---

## 27. Final product pitch

```text
Echo is a personal cultural collection.

You collect the works that shaped you, and the ones still waiting to be discovered.
Every work becomes a card. Some cards are open, greyed, and waiting. Others are revealed with a memory, an emotion, and a short echo of what stayed.

Echo helps you build a gallery of your cultural life: what you lived, what calls you, and the invisible links between them.
```

Short version:

```text
Collect what stayed. Keep what calls.
```
