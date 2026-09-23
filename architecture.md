# Readr Architecture

Readr is a personal-use iOS app for reading webnovel and manhwa content through
site-specific `Source` plugins behind a common contract.

This document is the **normative architecture guide**. It defines durable layer
rules, contracts, invariants, and architectural decisions. It does **not** own
file-by-file repository mapping; use `codemap.md` and per-folder `codemap.md`
documents for current implementation locations.

> **Status: foundation, persistence, source runtime, and initial plugins.** The rules below are
> binding. The contracts they govern — domain models, the `Source` protocol,
> source identity, the composition root, the app shell, the SwiftData store with
> its migration plan, and the HTTP/HTML/caching runtime behind `Source` — are
> implemented, along with the FreeWebNovel and AsuraScans plugins. Screens,
> downloads, and Spotlight are not.

---

## 1. Purpose and scope

Readr has three core architectural goals:

1. keep site-specific scraping isolated behind a stable plugin boundary
2. keep domain contracts framework-free and testable without a simulator
3. keep novel and manhwa reading experiences distinct where their content shapes
   genuinely differ, while sharing one Reader screen and control layout

Readr is a ground-up reimplementation of
[ReaderParser](https://github.com/PedrocaODev/ReaderParser) — an Android app with
the same purpose. It is not a fork and shares no code. It deliberately inherits
ReaderParser's architectural boundaries, invariants, and documentation model, and
deliberately does **not** inherit its interface: the UI is designed for iOS rather
than translated from Jetpack Compose. Section 9 records where that divergence is
load-bearing.

The app is a single Xcode target. The architectural boundaries below apply anyway.

Core stack, at a stable-summary level: SwiftUI for UI, Swift Concurrency for
async and state, `URLSession` + SwiftSoup for remote content, SwiftData for
structured persistence, `UserDefaults` for preferences, `BGTaskScheduler` and
background `URLSession` for work outside the foreground, and a hand-rolled
composition root for dependency injection.

| Concern | Choice |
| --- | --- |
| UI | SwiftUI |
| Async / state | async/await, `AsyncStream`, `@Observable` |
| HTTP | `URLSession` |
| HTML parsing | SwiftSoup |
| JSON | `Codable` |
| Database | SwiftData |
| Preferences | `UserDefaults` behind `SettingsStore` |
| Images | Nuke |
| Background | `BGTaskScheduler`, background `URLSession` |
| DI | `AppContainer` composition root via SwiftUI `Environment` |
| System search | Core Spotlight |
| Deployment target | iOS 26.0 |
| Language mode | Swift 6, strict concurrency `complete` |
| Devices | iPhone only |

---

## 2. Architectural principles

- **Layered design:** presentation depends on domain contracts, not concrete
  storage or source implementations.
- **Stable plugin boundary:** supported sites integrate through the `Source`
  contract so site churn does not leak across the app.
- **Pure domain:** domain models and repository contracts stay free of SwiftUI,
  SwiftData, `URLSession`, and SwiftSoup types.
- **Explicit ownership:** repositories coordinate remote and local data; source
  plugins fetch and parse remote content; UI renders state and forwards actions.
- **Unified reader with content-specific renderers:** one Reader screen renders
  both text and image content through dedicated renderers while sharing
  immersive controls.

---

## 3. Layer model and dependency rules

Calls go down the stack; data and state flow back up.

| Layer | Responsibility | Must not depend on |
| --- | --- | --- |
| UI | SwiftUI screens, stateless content views, navigation wiring | `SourceRegistry`, concrete sources, SwiftData, `URLSession` |
| Presentation | `@Observable` models, `State`, user actions/effects | concrete sources, SwiftData models, raw HTTP |
| Domain | Immutable models, repository protocols, use cases | SwiftUI, SwiftData, `URLSession`, SwiftSoup |
| Data | Repository implementations and orchestration | UI concerns |
| Source plugins | Remote fetch + parse behind `Source` | presentation models, navigation, SwiftData |
| Infrastructure | SwiftData, `UserDefaults`, filesystem, `URLSession`, `BGTaskScheduler`, DI | higher-level feature policy |

Rules:

- Lower layers never import higher layers.
- Presentation models never reference `SourceRegistry` or concrete `Source`s.
- Network calls live only inside `Source` implementations or repositories.
- Repositories are the only layer allowed to coordinate both source plugins and
  local storage.
- `*Screen` wires the model; `*Content` is the stateless `#Preview` target.

---

## 4. Core contracts and invariants

The following rules are stable across refactors and file moves.

1. Domain code has **zero** SwiftUI, SwiftData, `URLSession`, or SwiftSoup imports.
2. Network calls live only inside `Source` implementations or repositories.
3. Presentation models never reference `SourceRegistry` or a concrete `Source`.
4. One Reader screen with content-specific renderers for text and image pages.
5. `ChapterContent` stays an enum with exactly `.text(html:)` and `.pages(imageURLs:)`.
6. Domain models are immutable `struct`s conforming to `Sendable`.
7. No blocking waits on the main actor. No `DispatchSemaphore`, no `.wait()`, no
   synchronous I/O in production code.
8. `*Screen` wires the model; `*Content` is the stateless `#Preview` target.
9. Series and chapter identity is `(sourceID, url)`.
10. Downloads stay in Application Support, excluded from iCloud backup.
11. `sourceID` is derived with an **explicitly stable** hash — never `Hasher`.
12. SwiftData `@Model` classes are persistence types, never domain types.

Invariants 11 and 12 have no ReaderParser counterpart. They exist because Swift
and SwiftData make specific mistakes easy; sections 4.1 and 6 explain why each is
load-bearing.

### 4.1 Stable source identity

`sourceID` participates in persistence identity: it is half of the
`(sourceID, url)` key under which every series, chapter, progress record, and
downloaded file is stored. It must therefore produce the same value for the same
source on every launch, on every device, forever.

Swift's standard `Hasher` is **seeded randomly per process**. Using
`hashValue`, `Hashable` synthesis, or `Hasher` to derive `sourceID` would produce
a different identifier on every app launch, silently orphaning the entire library
and every downloaded chapter. Nothing would crash; the library would simply appear
empty.

`computeSourceID(name:lang:type:)` must therefore use an explicit, specified
algorithm — FNV-1a 64 or the leading 8 bytes of SHA-256 over
`"\(name)/\(lang)/\(type.rawValue)"` — and must be covered by a test asserting a
hardcoded expected value for a known input. That test is the guard rail; it must
never be updated to match changed output.

`type.rawValue`, never `\(type)`. The two produce identical bytes today, so the
guard-rail test cannot tell them apart, and substituting one for the other would
pass every test in the repository. They diverge the moment a `ContentType` case is
renamed — at which point the interpolated form re-keys every stored series,
chapter, and downloaded file, and the guard rail still passes because its input
strings never changed. The raw values are frozen for this reason.

The same applies to the other two components, and less visibly. `name` and `lang`
are not display strings that happen to be hashed; they are persisted format.
Renaming a shipped source from `"Novel Site"` to `"NovelSite"` orphans that site's
entire library exactly as a hash change would. `computeSourceID`'s own test cannot
catch this, because each plugin derives its `id` from its own strings — so **every
shipped plugin carries a test asserting its own hardcoded `id`**, and a shipped
source's `name` and `lang` are frozen once released.

Source IDs are computed, never hand-picked.

### 4.2 Contract shapes

```swift
enum ChapterContent: Sendable {
    case text(html: String)
    case pages(imageURLs: [URL])
}
```

```swift
protocol Source: Sendable {
    var id: Int64 { get }
    var name: String { get }
    var lang: String { get }
    var baseURL: URL { get }
    var type: ContentType { get }

    func supports(_ filter: Filter) -> Bool
    func popular(page: Int) async throws -> SeriesPage
    func latest(page: Int) async throws -> SeriesPage
    func search(query: String, page: Int, filters: FilterList) async throws -> SeriesPage
    func seriesDetails(for series: Series) async throws -> Series
    func chapterList(for series: Series) async throws -> [Chapter]
    func chapterContent(for chapter: Chapter) async throws -> ChapterContent
}
```

The app depends on this protocol, not on concrete site types. Changing it
requires explicit human approval.

---

## 5. Source plugin model

Each supported site is implemented as a `Source` plugin.

- A plugin owns request construction, response parsing, and mapping into domain
  models.
- Plugins may extend shared helpers such as `HTMLSource`, but that base type is a
  convenience, not the architectural contract.
- Plugin implementations are selected through `SourceRegistry` by `sourceID`.
- `SourceRegistry` is a static `[Int64: any Source]` built by the composition
  root. There is no dynamic loading — iOS does not permit it, and the app does
  not need it.
- Sources **throw** on error. They do not log, do not catch, and do not return
  `nil` sentinels. Error policy belongs to repositories.

Architectural consequence: adding or changing a site should primarily affect the
plugin implementation, its registration, and its tests, not the UI contract.

---

## 6. Persistence and ownership boundaries

Readr intentionally splits persistence by concern:

- **SwiftData** stores structured metadata and state such as library membership,
  chapter progress, and download queue state.
- **Filesystem** stores downloaded chapter payloads.
- **`UserDefaults`** stores user preferences and reader settings, behind the
  `SettingsStore` protocol so the domain never sees it.

### 6.1 `@Model` types are not domain types

SwiftData's `@Model` macro requires reference types, attaches persistence
machinery to every stored property, and binds instances to a `ModelContext`.
Those are all reasonable for a storage layer and all disqualifying for a domain
model that must be immutable, `Sendable`, and constructible in a plain unit test.

`@Model` classes therefore live in `Data/Local/Database/` and never cross the
repository boundary. Mappers translate them to and from the `struct` domain
models, exactly as Room entities are mapped in the app Readr descends from, and
for the same reason.

### 6.2 Ownership rules

- Repositories translate between domain models and persistence models.
- Source plugins do not write to SwiftData, `UserDefaults`, or download storage.
- Presentation models do not talk directly to `ModelContext`, files, or network
  clients.
- Schema changes require a `VersionedSchema` plus a `SchemaMigrationPlan` stage.
  Destructive migration is forbidden — deleting the store to resolve a schema
  mismatch destroys the user's library and reading progress.

### 6.3 Download storage

Downloads live under
`Application Support/Readr/Downloads/<sourceID>/<seriesKey>/<chapterKey>/`, with
`isExcludedFromBackup` set on the `Downloads` directory.

Application Support rather than Caches, because the system may evict Caches under
disk pressure and offline reading is the entire point of the feature. Excluded
from backup, because re-downloadable content must not consume the user's iCloud
quota — this is also an App Review requirement, which Readr does not face, but the
behavior is correct regardless.

---

## 7. High-level runtime and data flow

1. `ReadrApp` builds `AppContainer`, the composition root, and injects it into
   the SwiftUI `Environment`.
2. A screen forwards user actions to its `@Observable` model.
3. The model calls domain repository protocols.
4. Repository implementations decide whether to serve local state, refresh from a
   `Source`, or combine both.
5. When remote data is required, the repository resolves the site via
   `SourceRegistry[sourceID]` and calls the `Source` contract.
6. Source plugins fetch and parse remote content into domain models.
7. Repositories persist or merge results, then expose state back to presentation.
8. Background tasks reuse the same repository/source/storage graph outside the UI
   lifecycle.

Reader navigation opens one Reader destination with an explicit content type. The
screen branches once on `ChapterContent` to select the renderer:

- `.text(html:)` uses the attributed-text renderer.
- `.pages(imageURLs:)` uses the image-page renderer.

### 7.1 Dependency injection

There is no Hilt equivalent and Readr does not adopt a DI framework. `AppContainer`
is a plain type built once in `ReadrApp` that owns the `ModelContainer`, the
`URLSession`, the `SourceRegistry`, and every repository. It reaches screens
through the SwiftUI `Environment`.

Views never construct dependencies. Presentation models receive repositories
through their initializer, which is also what makes them testable with hand-rolled
fakes and no container at all.

---

## 8. Key architectural decisions and trade-offs

### Unified reader with content-specific renderers

One Reader screen shares immersive controls, navigation, and state management
while keeping text and image rendering as private views selected by
`ChapterContent`. This eliminates duplicated navigation, effects, and control
logic without introducing a polymorphic renderer abstraction.

### Repositories own orchestration

Repositories are the only layer allowed to see both plugin output and local
storage. This keeps presentation models simple and keeps site code focused on
remote parsing instead of app state policy.

### Domain stays framework-free

Keeping domain contracts plain Swift preserves testability and prevents SwiftUI,
SwiftData, or networking concerns from spreading upward. A domain test must run
without a simulator, a `ModelContainer`, or a network stub.

### Background execution is best-effort — accepted limitation

This is the one place where Readr is materially weaker than the Android app it
descends from, and the constraint is the platform's, not the design's.

`BGTaskScheduler` offers no delivery guarantee: iOS decides whether and when a
registered task runs, based on usage patterns, battery, and thermal state. A
`WorkManager` periodic job that reliably surfaces new chapters overnight has no
faithful counterpart.

Readr therefore treats background library refresh as an optimization, never as a
correctness requirement:

- `BGAppRefreshTask` (`dev.opus.readr.refresh.library`) refreshes the library when
  the system allows it.
- A foreground refresh on app activation is the actual guarantee. The library is
  always correct by the time the user looks at it.
- No feature may assume a background task ran.

Chapter downloads are different and stronger: background `URLSession` transfers do
survive app suspension and termination, and are handed to the system rather than
scheduled speculatively. `BGProcessingTask`
(`dev.opus.readr.process.downloads`) drains queue bookkeeping around them.

### Nuke over `AsyncImage`

`AsyncImage` is built in and has no explicit cache ceiling, no prefetching, and no
request coalescing. A webtoon chapter is a long vertical run of large images, which
makes all three matter: without a bounded memory cache and lookahead prefetch, the
reader either stutters or gets terminated for memory.

Nuke is therefore a deliberate dependency, not a default. It is the only
third-party UI dependency, and it is confined to the image-page renderer and the
cover-art component.

### Single target, logical boundaries

The app is a single Xcode target. That does not relax the dependency rules above.
Nothing enforces them at compile time, so `reviewer` enforces them at review time
— which is precisely why they are written down here.

### XcodeGen over a committed project file

`project.yml` is the source of truth; `Readr.xcodeproj` is generated and
gitignored. A checked-in `.pbxproj` is unreadable in review, conflicts on nearly
every parallel change, and is a poor thing to ask an agent to edit. A 100-line
YAML file is reviewable, diffable, and hard to corrupt.

---

## 9. Interface adaptation

Readr replicates ReaderParser's feature set. It does not replicate its interface.
Ported Material layouts feel wrong on iOS, and "matching the Android app" is not a
goal the user has. This section records the divergences that are architectural
rather than cosmetic.

**App shell.** A `TabView` with Library, Browse, Downloads, and Settings replaces
the navigation drawer. Series and Reader are pushed destinations, not tabs.

**Navigation.** A `NavigationStack` per tab with a typed path enum replaces the
central `NavGraph`. Reader is presented as a full-screen cover rather than a
pushed destination, so it escapes the tab bar and the navigation chrome.

**Reader chrome.** Tap toggles overlay controls, with `.statusBarHidden` and
`.persistentSystemOverlays(.hidden)` for immersion. The back gesture is the
system edge swipe, which means the reader's horizontal paging gesture must not
start at the leading screen edge.

**Text rendering.** `.text(html:)` is rendered as an `AttributedString` in a native
text view rather than in a web view. The domain still carries HTML — the contract
is unchanged — but the renderer is native, which is what makes Dynamic Type,
text selection, reader themes, and system typography work. A web view would be a
faster port and a worse reader.

**Platform affordances** replace their Material equivalents directly: `.searchable`
for search fields, `.refreshable` for pull-to-refresh, swipe actions and context
menus for per-item operations, `ContentUnavailableView` for empty states,
`.sensoryFeedback` on page turns, and the share sheet for outbound links.

**System search.** Core Spotlight indexes library series via `CSSearchableIndex`,
replacing ReaderParser's Samsung Search integration. Both are the same idea — make
the library findable from the OS — and the requirements port almost unchanged.

**Dynamic Type is honored throughout**, including in the reader. Fixed point sizes
are a bug in a reading app.

---

## 10. Relationship to `codemap.md`

Use the architecture and codemap documents by responsibility:

- **Update `architecture.md`** when layer rules, contracts, invariants, or
  architectural decisions change.
- **Update `codemap.md`** when structure, entry points, or implementation
  locations change.
- **Update both** when both the rules and the concrete structure changed, but do
  not duplicate the same detail in both places.

Start with `codemap.md` for codebase navigation. Read a folder's `codemap.md` for
local implementation maps.
