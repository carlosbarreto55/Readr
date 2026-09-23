# Codemap: `Data/Local/Search/`

> **Implemented in M9.**

Core Spotlight integration — the iOS counterpart to ReaderParser's Samsung Search
support. Normative behavior is in
`openspec/specs/spotlight-indexable-series/spec.md` and
`openspec/specs/library-search-via-spotlight/spec.md`.

| File | Responsibility |
| --- | --- |
| `SpotlightIndexer.swift` | `SeriesIndexing`, the non-throwing seam, and its implementation over `CSSearchableIndex.default()` in domain `dev.opus.readr.series` |
| `SpotlightAttributes.swift` | A series → `CSSearchableItemAttributeSet`: display title, source, author, genres, synopsis, local thumbnail. Series-level only. |
| `SpotlightIdentifier.swift` | `series|<sourceID>|<url>` — the one place the item identifier is encoded and decoded |
| `SpotlightThumbnailCache.swift` | Cover thumbnails as local files in Caches, so a launch rebuild does not re-fetch every cover |

Indexing is a projection of library state, never a source of truth. The writer
is `Data/Repository/SpotlightProjection`, a library observer; the index is
rebuilt from the library at every launch. A lost or rebuilt index never loses
user data, and an index write that fails is never surfaced.
