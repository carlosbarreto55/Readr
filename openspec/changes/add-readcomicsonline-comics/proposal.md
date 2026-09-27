## Why

Readr reads web novels, manhwa, and manga, but not western comics. Readers want current Marvel and DC runs such as Absolute Batman, The Amazing Spider-Man, and Superman. They should be able to discover, save, download, and read them through the same app flows, in the left-to-right page order comics are drawn for.

## What Changes

- Add ReadComicsOnline (`readcomicsonline.lol`) as a registered English western-comics source, with catalog, new releases, search, series details, an issue list, and ordered page extraction. It was chosen after a survey of comic sites (2026-09-27) because it is the one reachable site with server-rendered markup, no bot challenge, and page images that load without special headers.
- Add a distinct `comic` content type throughout browsing, library filtering, chapter downloads, offline payloads, and source settings, while preserving the existing two-case `ChapterContent` shape.
- Render comics as paged left-to-right by default, and let the reader switch comics to vertical scrolling from the Reader or from Settings. Comics get their own layout preference, so choosing one never changes the manhwa or manga layout.
- Label comic chapters as issues in series and reader surfaces.
- Add fixture-backed source tests and focused content-type, reader, preference, library, and download tests.

## Non-goals

- No change to the `Source` protocol, source-ID algorithm, SwiftData identity, or app target structure.
- No WebView, cookie harvesting, or bot-challenge workaround. Sites that require one, such as ReadComicOnline.li and xoxocomic, stay out of scope.
- No publisher-filter UI in this change. Marvel, DC, and Image titles appear in the shared catalog and search.
- No new third-party dependency and no non-English catalogs.
- No change to novel, manhwa, or manga reading behavior.

## Capabilities

### New Capabilities

- `readcomicsonline-comics-source`: ReadComicsOnline discovery, metadata, issue listing, and page parsing.

### Modified Capabilities

- `source-contract`: A source may represent western comics using the existing image-page chapter shape.
- `unified-reader-screen`: Comics use the shared reader. They open paged left-to-right by default and have their own switchable layout preference.
- `library-filtering`: Comics appear as a distinct, persisted library filter.
- `download-offline-reader`: Comic issues download and reopen offline the same way manhwa and manga chapters do.

## Impact

- New plugin and fixtures under `Readr/Sources/ReadComicsOnline/` and `ReadrTests/Fixtures/readcomicsonline/`.
- Small updates to domain content-type mapping, content-shape validation, reader preferences, HTML source dispatch, registration, download and payload handling, settings, library filters, series labels, and the image reader.
- Existing saved novel, manhwa, and manga values and behaviors remain valid.
- The MODIFIED requirements are written against the main specs as they stand after `add-mangapill-manga`, `add-reader-zoom`, and `add-app-theme` were archived.
