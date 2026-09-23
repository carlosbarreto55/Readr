## Why

After M6 a reader can find a series and see its chapters but cannot read one:
opening a chapter shows a "not built yet" alert. The Reader is the product. It
is also where two contracts meet for the first time — `ChapterContent`'s two
shapes and the reader's progress — so its behavior needs to be pinned before
downloads (M8) start serving stored payloads to it.

## What Changes

- Present one Reader, full-screen and outside the tab chrome, for every chapter
  opened from a series, with the route's content type.
- Render `.text(html:)` as native attributed text honoring Dynamic Type, the
  selected reader theme, font, and text size; render `.pages(imageURLs:)` as a
  vertical webtoon run or horizontally paged, with lookahead prefetch.
- Shared tap-to-toggle chrome: back, previous/next chapter (disabled at the
  ends, never hidden), chapter list, reader settings, and progress. Hiding the
  chrome hides the status bar and home indicator.
- Reserve the leading screen edge for a back swipe, so paging never starts there.
- Record reading position as the reader reads, restore it on reopen, and mark a
  chapter read when its end is reached.
- A route/content mismatch triggers one forced fetch; a second mismatch is a
  retryable unexpected-content error.
- Replace the Settings placeholder with reader appearance, sources, and a reset.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `unified-reader-screen`: add requirements for reader appearance preferences,
  and for chapters of series outside the library, whose progress is not stored
  because there is no library record to store it against.

## Impact

- **Domain:** reader preference values and keys; a chapter repository contract
  (reading-order chapter list, content, progress); `LibraryRepository` records
  progress; `CatalogRepository` fetches chapter content.
- **Data:** `DefaultChapterRepository`; the catalog repository fetches content
  uncached; the SwiftData repository writes progress and series last-read time.
- **Core:** an HTML-to-text-blocks parser (SwiftSoup), run off the main actor.
- **UI:** `Readr/UI/Reader/` (four files plus the two renderers named in its
  codemap), `Readr/UI/Settings/` (four files), reader presentation in the shell,
  reader colors in `UI/Theme/`.

## Non-goals

- Downloads and offline payloads (M8). The chapter repository's bypass flag is
  defined here and gains meaning when stored payloads exist.
- The download control in reader chrome, which arrives with downloads in M8.
- Spotlight (M9).
- A web view renderer, zoom-to-pan for manhwa pages, or per-series reader
  settings.
- Schema changes: progress fields already exist in v2.
