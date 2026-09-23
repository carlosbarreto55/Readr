# Codemap: `Domain/Model/`

Immutable `Sendable` structs and enums. No reference types, no persistence
annotations, no framework imports beyond Foundation.

| Type | Shape |
| --- | --- |
| `Series` | struct — identity is `(sourceID, url)`, exposed as `SeriesID` |
| `LibraryItem` | struct — saved `Series` plus reader-owned date-added and last-read timestamps |
| `LibraryChapter` | struct — stored `Chapter` plus read state, position, source position, and whether the source still lists it |
| `ChapterReadingOrder` | enum namespace — first-chapter-first ordering and the continue-reading target |
| `Series+DisplayTitle` | `displayTitle` — the title, or a URL-derived placeholder when it is blank |
| `Chapter` | struct — identity is `(sourceID, url)`, exposed as `ChapterID` |
| `ChapterContent` | enum — exactly `.text(html:)` and `.pages(imageURLs:)` |
| `ContentType` | enum — `.novel`, `.manhwa`, with frozen raw values |
| `SeriesStatus` | enum — ongoing, completed, hiatus, cancelled, unknown |
| `SeriesPage` | struct — one page of catalog results plus a has-more flag |
| `SourceInfo` | struct — source metadata exposed to the UI |
| `Filter` / `FilterList` | catalog filtering primitives |

Planned, each arriving with the change that needs it:

| Type | Shape |
| --- | --- |
| `DownloadItem` / `DownloadState` | queue entry and its lifecycle |
| `AppSettings` / `AppTheme` | user preferences |
| `ManhwaLayout` / `ManhwaZoom` | reader display preferences |
| `LibrarySearchResult` | a Spotlight or in-app search hit |

`Series` and `Chapter` define equality and hashing on `(sourceID, url)` alone, so
refreshed metadata never changes which record a value refers to.

That propagates into containers: `[Series] == [Series]` and `SeriesPage ==
SeriesPage` also ignore metadata. **Change detection must compare fields
explicitly.** A repository written as `guard fetched != cached else { return }`
would silently discard refreshed titles, covers, and statuses, and a test
comparing entries with `==` would agree with it.

`ChapterContent` having exactly two cases is invariant 5. Adding a third case is
an architecture change, not a feature.

`ContentType`'s raw values are written out rather than defaulted, because
`computeSourceID` hashes them — see `Core/Util/codemap.md`.
