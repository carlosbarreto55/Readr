# Codemap: `Data/Local/Search/`

> **No implementation yet.**

Core Spotlight integration — the iOS counterpart to ReaderParser's Samsung Search
support. Normative behavior is in
`openspec/specs/spotlight-indexable-series/spec.md` and
`openspec/specs/library-search-via-spotlight/spec.md`.

Planned contents:

| File | Responsibility |
| --- | --- |
| `SpotlightIndexer.swift` | Adds, updates, and removes `CSSearchableItem`s as library membership changes |
| `SpotlightAttributes.swift` | Domain `Series` → `CSSearchableItemAttributeSet` |
| `SpotlightDeepLink.swift` | Resolves a Spotlight activity back to `(sourceID, url)` |

Indexing is a projection of library state, never a source of truth. A lost or
rebuilt index must never lose user data.
