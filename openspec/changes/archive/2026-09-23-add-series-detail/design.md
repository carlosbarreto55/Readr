## Context

M1–M5 built the domain vocabulary, schema v1, the source runtime, two live
plugins, and the Library and Browse catalogs. Both catalogs push a typed
`.series(SeriesID)` route, which currently lands on a placeholder.

`LibraryRepository.storeChapters(_:for:)` already updates metadata in place and
preserves read state, but it cannot express two things the normative
`chapter-refresh-state-preservation` spec requires: a chapter the source stopped
listing must be *marked*, and an empty refresh must be a failure. Its doc comment
also leaves chapter order explicitly open "until M6 first refreshes a chapter
list against a live source". The two shipped plugins answer that question
decisively: FreeWebNovel lists oldest-first, AsuraScans newest-first.

Sequencing: M6 of the nine milestones in the M1 migration plan.

## Goals / Non-Goals

**Goals:**

- A series opens instantly from stored state, including offline.
- A refresh can never lose reading state, never silently delete a chapter, and
  never commit half a merge.
- Blank-titled saved series are repaired by a library refresh and are always
  displayable, openable, and removable in the meantime.
- Presentation reaches all of this through domain protocols only.

**Non-Goals:**

- Presenting the Reader (M7), downloads (M8), Spotlight (M9).
- Background refresh via `BGTaskScheduler` (registered in M8 with the download
  task; the foreground refresh is the guarantee either way).

## Decisions

### Schema v2 stores source position and upstream presence

`ChapterEntity` gains `sourceIndex: Int` (position in the most recent list the
source returned) and `isListedUpstream: Bool`. Both have defaults, so v1 → v2 is
a lightweight stage. Existing rows migrate as `sourceIndex = 0`,
`isListedUpstream = true`; the first refresh assigns real positions.

To keep v1 frozen, the v1 model classes move *inside* `SchemaV1` unchanged, v2
defines its own, and top-level `SeriesEntity` / `ChapterEntity` become
typealiases to the current version. Entity names are the unqualified class
names, so the v1 store on disk is recognized by the v1 schema exactly as before.
Identity (`key`), uniqueness, and the cascade rule are unchanged.

*Alternative considered — order by chapter number only.* Rejected: numbers are
optional and parsed from display names, so a list with one unparseable name would
have no defined order.

### Reading order is a pure domain function

`ChapterReadingOrder.sorted(_:)` orders `[LibraryChapter]`:

1. Every chapter numbered → ascending number, ties by source position.
2. Otherwise → source position, reversed when the source's first and last
   numbered chapters show it lists newest-first.

Unlisted chapters keep their last `sourceIndex`, so they stay where the reader
last saw them. The function is framework-free and tested without a store.

### The refresh merge is one repository method, committed once

`LibraryRepository.mergeChapterList(_:for:)` is the refresh merge:

- empty input → throws `LibraryRepositoryError.emptyChapterList`, touching nothing;
- foreign chapters → throws `chapterNotInSeries` before any write;
- stored chapters present in the list → metadata and `sourceIndex` updated,
  `isListedUpstream = true`, reader state untouched;
- new chapters → inserted unread at their `sourceIndex`;
- stored chapters absent → `isListedUpstream = false`, nothing deleted.

All of it is applied to the actor's `ModelContext` and saved once; if anything
throws, the context is rolled back, so a failed refresh leaves the store exactly
as it was. `storeChapters(_:for:)` keeps its narrower additive meaning.

`chapters(for:)` stays for callers that need plain `Chapter`s;
`libraryChapters(for:)` returns `[LibraryChapter]` (chapter + read state +
position + listed flag) already in reading order.

Read state is written by `setRead(_:isRead:in:)`. Marking unread resets the
position to 0; marking read sets it to 1.

### A series repository owns detail orchestration

New domain protocol `SeriesRepository`, implemented by `DefaultSeriesRepository`
in `Data/Repository/` over `LibraryRepository` and `CatalogRepository` (protocols,
so it is tested with fakes):

- `stored(_:)` → the saved series and its library chapters, or `nil`. Local only.
- `refresh(_:)` → details and chapters from the source with the caches bypassed.
  A saved series has the enriched metadata saved and the chapter list merged,
  and the merged stored state is returned. An unsaved series returns remote
  chapters with default state and writes nothing.
- `seed(for:)` → a `Series` to show before details arrive: the stored one, else
  the listing entry the catalog last returned for that identity, else a bare
  series carrying only identity and its source's content type.
- `refreshLibrary()` → the library refresh (below).

`CatalogRepository` gains `knownSeries(_:)`: `DefaultCatalogRepository` remembers
the entries of every page it returns in a bounded map keyed by `SeriesID`. The
route therefore stays an identity, as `app-shell-navigation` requires, without
the detail screen fetching a series it has no title for.

*Alternative considered — put `Series` in the route.* Rejected: routes carry
identity so they compare equal for the same subject and cannot go stale.

### Library refresh repairs blank titles and refreshes chapters

`refreshLibrary()` walks saved series sequentially (bounded by the HTTP client's
per-host limit anyway). For each: if the title is blank, fetch details with the
cache bypassed and save only a non-blank title; then refresh and merge chapters.
A per-series failure is counted and skipped — the series stays saved with its
blank title and is retried next refresh. It returns a `LibraryRefreshReport`
(refreshed / failed / repaired counts).

Triggers: Library's `.refreshable`, and `RootTabView` on `scenePhase == .active`
at most once per 15 minutes.

### Blank titles display a URL-derived placeholder

`Series.displayTitle` returns the title, or — when blank — the last meaningful
URL path component de-slugged and capitalized ("the-swordmaster-123" →
"The Swordmaster 123"), falling back to the host. Cards, the detail screen, and
Library's title sort use it. Identity never depends on it.

### Series screen

Four files under `UI/Series/`. `SeriesModel(id:series:catalog:)` receives
`SeriesRepository` and `LibraryRepository` via `init`.

On appear: `stored(id)` → render immediately if saved; otherwise `seed(for:)`.
Then `refresh`. Phases: `loading` (nothing to show yet), `loaded`, `failed`
(nothing to show, retry). A refresh failure while content is shown becomes a
dismissible banner rather than replacing the content.

Actions: toggle library (optimistic, rollback on failure; saving also stores the
chapter list currently shown), mark read/unread (swipe action and context menu),
continue reading, open chapter, retry, refresh (`.refreshable`). Opening a
chapter emits `.openReader(ReaderRoute)`; until M7 presents it, the screen shows
an explanatory alert rather than a silent no-op.

Continue target: the first unread chapter after the last read one in reading
order, else the first chapter.

## Risks / Trade-offs

- **Reusing class names across schema versions** → entity names are unqualified
  class names by SwiftData's design; the migration test writes a v1 store on
  disk, reopens it through the plan, and asserts every field survived.
- **`knownSeries` memory** → bounded (500 entries, oldest evicted); a miss only
  degrades the pre-detail seed to a bare title placeholder.
- **Activation refresh cost** → throttled to once per 15 minutes; sequential per
  series; failures are counted, not surfaced as errors.
- **Order heuristic misjudges a mixed list** → the fallback is the source's own
  order, which is never worse than today's undefined order.

## Migration Plan

Schema v1 → v2, lightweight, adding two defaulted attributes. Existing chapters
keep identity, reader state, and relationships. Rollback is `git revert`; a store
already migrated to v2 would not open under v1, which is why the migration is
tested on disk before shipping.

## Open Questions

None blocking. Whether unsaved series should record reading progress is decided
in M7 with the Reader.
