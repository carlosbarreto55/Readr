## Why

Readr currently offers web novels and manhwa, but not Japanese manga. A reader should be able to discover, save, download, and read manga through the same app flows, with page turns in Japanese right-to-left order.

## What Changes

- Add MangaPill as a registered English-language Japanese manga source, with catalog, search, details, chapters, and ordered page extraction.
- Add a distinct `manga` content type throughout browsing, library filtering, chapter downloads, offline payloads, and source settings, while preserving the existing two-case `ChapterContent` shape.
- Render manga as paged right-to-left by default, retaining the shared reader chrome and progress behavior. Keep manhwa's existing vertical behavior and allow manga readers to choose vertical layout.
- Load MangaPill cover and chapter images with the site's required request header, including when using image caching and prefetching.
- Add fixture-backed source tests and focused reader, persistence, and download tests.

## Non-goals

- No changes to the `Source` protocol, source-ID algorithm, SwiftData identity, or app target structure.
- No new third-party dependency or support for untranslated Japanese-language catalogs.
- No change to novel text rendering or manhwa reading direction.

## Capabilities

### New Capabilities

- `mangapill-manga-source`: MangaPill discovery, metadata, chapter listing, and page parsing.

### Modified Capabilities

- `source-contract`: A source may represent manga using the existing image-page chapter shape.
- `unified-reader-screen`: Manga uses the shared reader with right-to-left paged navigation and a separate layout preference.
- `library-filtering`: Manga appears as a distinct, persisted library filter.
- `download-offline-reader`: Manga image chapters download and reopen offline like manhwa chapters.

## Impact

- New plugin and fixtures under `Readr/Sources/MangaPill/` and `ReadrTests/Fixtures/mangapill/`.
- Small updates to domain content-type mapping, HTML source dispatch, registration, download/payload handling, settings, library filters, and the image reader.
- Existing saved novel/manhwa values and behaviors remain valid.
