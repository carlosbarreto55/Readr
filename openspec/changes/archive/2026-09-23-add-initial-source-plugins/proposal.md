## Why

Readr has a complete source runtime but registers no sources, so every catalog
request is impossible and the app still cannot reach any reading content. M4
ports ReaderParser's two maintained sources so the runtime is exercised against
real novel and manhwa markup before catalog UI is built in M5.

## What Changes

- Add FreeWebNovel as an English novel source with popular and latest listings,
  search, series details, chapter lists, and cleaned chapter HTML.
- Add AsuraScans as an English manhwa source with browse and latest listings,
  search, series details, chapter lists, and image pages in reading order.
- Register both sources in the live composition root using the shared
  `HTTPClient`.
- Add saved, fixture-driven parser tests derived from ReaderParser's live-backed
  FreeWebNovel captures and directly observed AsuraScans markup, including
  hardcoded source-ID guard rails.
- Update source and repository maps to reflect that concrete plugins now ship.

## Capabilities

### New Capabilities

- `initial-source-plugins`: The observable catalogs, metadata, chapters, content
  shapes, and discovery behavior supplied by FreeWebNovel and AsuraScans.

### Modified Capabilities

None. The existing `source-contract` and M3 runtime are exercised as written;
their requirements do not change.

## Impact

- **New code:** `Readr/Sources/FreeWebNovel/FreeWebNovel.swift` and
  `Readr/Sources/AsuraScans/AsuraScans.swift`.
- **Composition:** `Readr/Core/DI/SourceRegistration.swift` returns two live
  sources instead of an empty array.
- **Tests and fixtures:** new source tests and saved HTML under
  `ReadrTests/Fixtures/freewebnovel/` and `ReadrTests/Fixtures/asurascans/`.
- **Runtime:** add a site-agnostic finite-latest-feed limit to `HTMLSource` so a
  one-page feed returns an empty later page without repeating a network request.
- **Dependencies:** none. Both plugins use `HTMLSource` and the already-declared
  SwiftSoup dependency.
- **Stored identity:** the shipped `name`, `lang`, and `ContentType` tuples become
  permanent identity inputs once users can save series from these sources.

## Non-goals

- Catalog, library, detail, or reader UI; those begin in M5.
- Adding filter cases or advertising unsupported remote filters. Neither initial
  source exposes a stable filter contract beyond text search.
- Porting FreeWebNovel's optional AJAX chapter-list optimization or AsuraScans's
  optional JSON chapter API. Both upstream sources have server-rendered HTML
  paths that preserve the shared runtime's request and parsing guarantees.
- Live-network tests. Tests always serve saved fixtures through the stubbed URL
  protocol.
