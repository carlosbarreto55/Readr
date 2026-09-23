## Why

A reader with a large library has no way to find a series except scrolling, and
the OS cannot find it at all. The two normative search capabilities —
`spotlight-indexable-series` and `library-search-via-spotlight` — are the last
milestone of the plan M1 laid out.

## What Changes

- Index every saved series in Core Spotlight — its display title (the
  placeholder for a blank title, never an empty string), source, author, genres,
  synopsis, and cover thumbnail where one can be fetched — under an identifier
  derived from `(sourceID, url)`.
- Update the indexed item whenever a saved series' metadata is saved again (a
  detail refresh, a title repair), and delete it when the series is removed.
- Treat the index as a projection: rebuild it from the library at every launch
  and on request from Settings; an indexing failure never fails or surfaces from
  the library operation that triggered it.
- Open a Spotlight result directly on its series in the Library tab; a result
  for a series no longer saved opens the app, explains, and removes the stale
  entry.
- Add in-app Library search: offline, case- and diacritic-insensitive, with an
  empty state that distinguishes "no match" from "empty library".

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `spotlight-indexable-series`: state when the projection is rebuilt — at launch
  and on the reader's request.

## Impact

- **Domain:** a system-search contract (deep-link resolution, rebuild) and the
  library search matching rule.
- **Data:** `Data/Local/Search/` (Spotlight indexer, attributes, identifier); a
  library observer that keeps the index in step; the system-search repository.
- **UI:** Library `.searchable`; Spotlight continuation handled by the shell
  through `NavigationState`; Rebuild Spotlight Index in Settings.
- **No new entitlement or `Info.plist` capability:** `CSSearchableIndex` and
  `CSSearchableItemActionType` continuation need neither.

## Non-goals

- Indexing chapters, chapter text, or page images — forbidden by
  `spotlight-indexable-series`.
- Searching remote catalogs from Library search; Browse already searches sources.
- A Core Spotlight index extension; the in-app rebuild at launch covers index
  loss.
