## Context

M6 emits `SeriesEffect.openReader(ReaderRoute)` and shows a placeholder alert.
`ReaderRoute` already carries source ID, series URL, chapter URL, and content
type, per `app-shell-navigation`. Schema v2 already stores `isRead`,
`readingPosition`, and `lastReadAt` per chapter and `lastReadAt` per series.
`architecture.md` §8–9 fix the shape: one screen, two private renderers selected
by `ChapterContent`, a full-screen cover, native attributed text, Nuke only in the
page renderer.

Sequencing: M7 of the nine milestones in the M1 migration plan.

## Goals / Non-Goals

**Goals:**

- One Reader destination, model, and state for both content types.
- Native, Dynamic-Type-honoring text; smooth, memory-bounded image runs.
- Progress that survives leaving and reopening a chapter.
- Reader appearance preferences, adjustable in the Reader and in Settings.

**Non-Goals:**

- Downloads (M8), Spotlight (M9), zoom, per-series settings.

## Decisions

### A chapter repository serves the Reader

Domain protocol `ChapterRepository`, implemented by `DefaultChapterRepository`
over `LibraryRepository` and `CatalogRepository`:

- `chapters(in:contentType:)` → the series' chapters in reading order. A saved
  series with stored chapters is served from the library; otherwise from the
  catalog (cached), as unread `LibraryChapter`s.
- `content(for:bypassingStored:)` → the chapter's content. In M7 always the
  source, through `CatalogRepository.chapterContent(for:)`, which is uncached:
  chapter bodies are large and read once. M8 makes stored payloads win unless
  `bypassingStored`.
- `recordProgress(_:in:position:reachedEnd:)` → `ProgressRecording.stored` when
  written, `.notInLibrary` when the series is not saved (nothing written).

`LibraryRepository.recordProgress` writes position, sets `isRead` once the end is
reached (it never un-reads a chapter on re-reading), and stamps `lastReadAt` on
the chapter and the series — which is what Library's Last Read sort reads.

*Alternative considered — auto-save a series on first read.* Rejected: library
membership is the reader's decision, and a silent save would also make it
Spotlight-indexed in M9.

### Progress is a fraction, recorded coarsely

Position is `0...1`: for text, the index of the first visible block over the
block count; for pages, the page index over the page count. The model persists
when the position moved by at least 5%, when the end is reached, and when the
chapter changes or the Reader closes. Restore scrolls to the stored fraction
unless the chapter is already read, which reopens at the start.

### HTML becomes text blocks off the main actor

`ChapterTextParser` (Core/Util, SwiftSoup) turns chapter HTML into
`[ChapterTextBlock]` — paragraphs, headings, quotes, separators — each a list of
runs with bold/italic flags. `<br>` breaks paragraphs, whitespace collapses,
scripts/styles are dropped. The model runs it in a detached task, so a long
chapter never parses on the main actor (invariant 7). The text renderer builds an
`AttributedString` per block from the reader's font, size, and theme; a block is
one `Text` with selection enabled, in a `LazyVStack`, so long chapters render
lazily.

*Alternative considered — `NSAttributedString(html:)`.* Rejected: it runs WebKit
on the main thread, is slow for long chapters, and imposes its own fonts.

### Text size scales Dynamic Type

The body size is a `@ScaledMetric` relative to `.body`, multiplied by the reader's
text-size setting (0.8×–2.0×). The system size still drives it; the setting only
offsets it, satisfying `architecture.md` §9 ("fixed point sizes are a bug").

### Page renderer: vertical run or horizontal pages

Vertical (default) is a `LazyVStack` of full-width `LazyImage`s; paged is a
horizontal paging `ScrollView`. Both track the visible page by
`scrollPosition(id:)`, prefetch the next three pages with Nuke's
`ImagePrefetcher`, and show a per-page placeholder and retry on failure. Page
turns in paged mode give selection haptics.

### The leading edge belongs to back

A transparent strip along the leading edge sits above both renderers. It absorbs
touches, so no scroll or paging gesture can begin there, and a rightward drag on
it closes the Reader — the edge-swipe back the platform would give a pushed view,
which a full-screen cover does not have.

### Chrome and presentation

`NavigationState.presentedReader` drives a `.fullScreenCover(item:)` in
`RootTabView`. The Series screen sets it from the effect; closing clears it and
bumps `libraryRevision`, so Library and Series re-read progress.

Chrome is an overlay: top bar (close, chapter and series title), bottom bar
(previous, chapter list, progress, reader settings, next). Tapping the reading
surface toggles it; hidden chrome sets `.statusBarHidden` and
`.persistentSystemOverlays(.hidden)`. Previous/next are disabled at the ends.
The chapter list and reader settings are sheets whose presentation is Reader
state — they are local panels, not navigation.

### Mismatch handling

After a load, `content.contentType` is compared with the route's. On mismatch the
model discards the payload and fetches once with `bypassingStored: true`; a second
mismatch is a retryable `unexpectedContent` failure. Nothing mismatched is ever
rendered.

### Reader preferences

Domain `ReaderTheme` (system/light/sepia/dark), `ReaderFontDesign`
(system/serif), `ReaderPageLayout` (vertical/paged), and a `Double` text scale,
each behind a `SettingKey` under `readr.reader.`. Reader colors live in
`UI/Theme/ReaderColors.swift`.

### Settings screen

Four files under `UI/Settings/`: reader appearance (the same keys), the registered
sources (name, language, type), app version, and Reset Settings (confirmation,
then `SettingsStore.removeAll()`, which leaves library data untouched).

## Risks / Trade-offs

- **Lazy text makes fractional restore approximate** → restore is by block, which
  lands on the paragraph the reader left, not the exact line.
- **Tap-to-toggle competes with text selection** → selection uses long-press;
  a single tap still toggles chrome.
- **Huge pages exhaust memory** → Nuke's bounded cache; only visible and three
  lookahead pages are requested.
- **Unsaved series lose progress** → stated in the Reader; saving the series from
  its detail screen starts recording.

## Migration Plan

No schema change. New settings keys resolve to defaults until written. Rollback is
`git revert`.

## Open Questions

None blocking.
