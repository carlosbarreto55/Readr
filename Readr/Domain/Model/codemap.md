# Codemap: `Domain/Model/`

> **No implementation yet.**

Immutable `Sendable` structs and enums. No reference types, no persistence
annotations, no framework imports.

Planned contents:

| Type | Shape |
| --- | --- |
| `Series` | struct — identity is `(sourceID, url)` |
| `Chapter` | struct — identity is `(sourceID, url)` |
| `ChapterContent` | enum — exactly `.text(html:)` and `.pages(imageURLs:)` |
| `ChapterWithState` | struct — chapter plus read/download state |
| `ContentType` | enum — `.novel`, `.manhwa` |
| `SeriesStatus` | enum — ongoing, completed, hiatus, cancelled, unknown |
| `SeriesPage` | struct — one page of catalog results plus a has-more flag |
| `SourceInfo` | struct — source metadata exposed to the UI |
| `Filter` / `FilterList` | catalog filtering primitives |
| `DownloadItem` / `DownloadState` | queue entry and its lifecycle |
| `AppSettings` / `AppTheme` | user preferences |
| `ManhwaLayout` / `ManhwaZoom` | reader display preferences |
| `LibrarySearchResult` | a Spotlight or in-app search hit |

`ChapterContent` having exactly two cases is invariant 5. Adding a third case is
an architecture change, not a feature.
