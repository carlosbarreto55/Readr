## Context

Readr has three registered HTML sources and one image-page renderer. Manga support (`add-mangapill-manga`) established the pattern for a new image content type. That pattern is a stable `ContentType` raw value, the unchanged two-case `ChapterContent` enum, a per-type layout preference, and a library filter.

A survey of western-comic sites on 2026-09-27 fetched each candidate directly.

| Site | Outcome |
| --- | --- |
| readcomicsonline.lol | Server-rendered with no challenge. About 207 series: 103 Marvel, 67 DC, plus Image. WebP pages on `cdn.readcomicsonline.lol` load without a Referer or cookies. robots.txt allows `/comic/` and `/search`. |
| xoxocomic.com | Catalog and issue lists render on the server, but every page-image URL returned HTML to non-browser requests. That is bot protection keyed to a real browser. |
| readcomiconline.li, readcomicsonline.ru, batcave.biz | Cloudflare challenge (403) |
| readallcomics.com | Origin down (522) |
| azcomix, comicextra, viewcomics | Parked domain or ad redirect |
| getcomics.org | Downloads only; no reader |

ReadComicsOnline is a Next.js site. Listings, series pages, and search results are plain `<a href="/comic/…">` markup. An issue page renders only page 1 as an `<img>`. The full ordered page list is in the embedded React Server Components payload (`self.__next_f.push(...)`), as escaped JSON of the form `"pages":[{"id":…,"pageNumber":1,"url":"https://cdn…/p001.webp"}, …]`. The site serves `/comics` (the full catalog), `/new-comics`, and `/search?q=` as single pages. Their `?page=` parameters return identical content.

## Goals / Non-Goals

**Goals:** ReadComicsOnline discovery, search, details, and issues; a distinct comic identity in the library and downloads; left-to-right paged reading by default, with a comic-only vertical option; and fixture-backed parsing.

**Non-Goals:** a publisher filter UI, WebView or cookie-based access to challenged sites, a new chapter-content case or source-protocol method, a new dependency, and a SwiftData schema revision.

## Decisions

1. **`ContentType.comic = "comic"`** is a new stable raw value (architecture invariant 11). `SeriesEntity.contentTypeRaw` is a `String`, so existing stores need no migration. Content-shape validation accepts `(.pages, .comic)`.
   *Alternative:* reuse `.manhwa` for comics. That would force vertical reading and merge comics into the manhwa library filter.

2. **`ReadComicsOnline` subclasses `HTMLSource`** and registers in `liveSources()`. popular is `/comics` and latest is `/new-comics`. Both are finite single pages, with `nextPageSelector`/`latestNextPageSelector` set to `nil`. search is `/search?q=` with no next page. Series elements are anchors whose path is exactly `/comic/<slug>`. Issue anchors are `/comic/<slug>/<issue>`, and `number` is the last path component when it parses as a `Double` (for example `24` or `1.1`). Selectors come from saved fixtures only (`Readr/Sources/AGENTS.md`).
   *Alternative:* use `/publisher/marvel` and `/publisher/dc` as popular and latest. That would hide Image titles and still needs a filter UI to be useful.

3. **Pages are read from the embedded payload, not from `<img>` tags.** `parsePages` scans the issue document's inline script data for the `pages` array. It unescapes the RSC string encoding, decodes the entries with `pageNumber` and `url`, sorts them by `pageNumber`, and throws `SourceError.requiredFieldMissing` when the array is missing or empty. This logic stays inside the plugin, and `HTMLSource` gains no Next.js awareness (source-contract: "Shared source base types SHALL stay site-agnostic").
   *Alternative:* synthesize `p001…pNNN.webp` URLs from a page count. That depends on a naming convention the site never promised and would break on non-WebP pages.

4. **Reader preferences add `comicPageLayout`** under a new key, defaulting to `.paged`. It mirrors `mangaPageLayout`. The Reader's layout picker and the Settings row write to the preference for the open content type. Paged comics use `.leftToRight` layout direction. Only manga uses `.rightToLeft`. Vertical comics keep source order.
   *Alternative:* share `pageLayout` with manhwa. Switching comics to paged would then flip manhwa too.

5. **Label branches become exhaustive `switch` statements.** `SeriesState` (subtitle), `SettingsContent` (source row), and `LibraryState` (filter title) use nested ternaries today that fall through to "Manhwa". A fourth case would be mislabeled silently. With a `switch`, the compiler flags every place a future content type must handle. Comics display "Comic" and "Comics".

6. **No image-request policy is needed.** The MangaPill referer rule is host-scoped and does not apply here. Offline downloads reuse the existing page-download path through the `.manhwa, .manga` branches in `HTMLSource` and `ChapterPayloadStore`, extended with `.comic`.

## Risks / Trade-offs

- **The site changes its RSC payload shape, or moves page URLs out of HTML.** → The fixture test pins the observed shape, and the parser throws a contextual error rather than returning an empty issue. The source remains isolated so it can be disabled.
- **A small catalog of about 207 series focused on current runs, without back issues from every era.** → This is accepted for a first comics source. xoxocomic, with a larger catalog, is the follow-up candidate once an on-device spike shows that `URLSession` receives its images.
- **Unpaginated `/comics` returns all 207 entries in a roughly 950 KB page.** → It is a single request with no pagination loop, the same as MangaPill's finite catalog. The metadata cache absorbs repeat visits.
- **Takedown or domain move, which is common for this site category.** → `baseURL` lives in one place. The source ID is derived from name and language, not domain (source-contract "Source identity SHALL be stable and derived"), so a domain swap keeps library identity.

## Migration Plan

Ship the new content type and the UserDefaults key additively. Existing records and settings need no migration. A rollback hides comic records until the feature returns and leaves their identities and payloads untouched.

## Open Questions

- Should a Marvel/DC/Image publisher filter follow, using `/publisher/<slug>` and `supports(_:)`? It is deferred until the filter UI can show source-specific filters.
