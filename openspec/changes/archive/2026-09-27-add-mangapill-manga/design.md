## Context

Readr has two registered HTML sources and one image-page renderer. MangaPill exposes server-rendered manga listings, series pages, chapter links, and ordered `data-src` page images. Its image CDN requires a MangaPill `Referer`; an unadorned Nuke image request receives HTTP 403. Existing downloaded page requests already carry a chapter referer. Manga needs a distinct content type for catalog and library identity, but shares the `.pages(imageURLs:)` payload shape with manhwa.

## Goals / Non-Goals

**Goals:** MangaPill discovery/search/details/chapters, distinct manga library and download behavior, reliable online images, and right-to-left paged manga reading with shared controls and progress.

**Non-Goals:** A new chapter-content enum case, a new source protocol method, a manga-only reader screen, another dependency, or a SwiftData schema revision.

## Decisions

1. `ContentType.manga` is a new stable raw value. The two-case `ChapterContent` enum remains unchanged. Callers validate content *shape* against content type: novel requires text, manhwa and manga require pages. This avoids falsely labeling every page payload as manhwa. Alternative: a new `.mangaPages` case duplicates the payload and violates the reader contract.
2. `MangaPill` subclasses `HTMLSource`, supplies observed selectors, and registers through `liveSources()`. Its catalog/search URLs include the site's manga type filter; a finite latest feed uses a manga-only catalog page if MangaPill has no reliably typed latest-chapter feed. Alternative: the mixed `/chapters` feed risks classifying manhwa as manga.
3. Reader preferences keep manhwa layout under the existing key and add a separate manga layout key defaulting to paged. In paged manga, visual page order is right-to-left: the first page is at the right, advancing moves left, and position remains the original zero-based chapter index. Vertical manga keeps top-to-bottom order. Alternative: reusing manhwa's preference would unexpectedly change existing readers' defaults.
4. Image request headers are applied by a generic Nuke request policy configured at the composition root from MangaPill's image host/referer rule, covering covers, page images, and prefetching without coupling presentation models to a concrete source. Other hosts are untouched. Offline page downloads retain their chapter referer.
5. All new parsing is fixture-backed; source requests use stubbed `URLProtocol`, and tests cover content-shape validation, layout direction/progress, settings persistence, and offline manga payloads.

## Risks / Trade-offs

- [MangaPill markup or anti-hotlink rules change] → Fixture tests pin observed markup; request policy is scoped to its image host and error UI stays retryable.
- [Recently-added catalog differs from latest chapter updates] → Label/describe the source feed accurately and avoid misrepresenting mixed content as Japanese manga.
- [RTL SwiftUI layout interacts with the system back gesture] → Keep the existing leading-edge reservation and test logical index restoration and forward progression independently of visual order.
- [A new raw content type reaches older switches] → Compile under Swift's exhaustive switching and test payload and filter round-trips; existing raw values are unchanged.

## Migration Plan

Ship the new type and UserDefaults key additively. Existing novel/manhwa records and settings require no data migration. Rolling back hides new manga records until the feature returns; it does not rewrite their identities or payloads.

## Open Questions

- Verify the manga-only listing's ordering and exact pagination markup against a current saved fixture before selecting its `latest` implementation.
