## Context

M8 introduced `ObservedLibraryRepository`, which notifies `LibraryChangeObserver`s
after a successful save or removal, precisely so the Spotlight projection could
attach without the library knowing it exists. `Series.displayTitle` (M6) already
defines the placeholder `library-blank-title-repair` requires Spotlight to index.
Every series route carries `(sourceID, url)`.

Sequencing: M9, the last of the nine milestones in the M1 migration plan.

## Goals / Non-Goals

**Goals:**

- The index is a projection: derivable from the library, never consulted as a
  source of truth, and never able to fail a library operation.
- A Spotlight result lands on its series; a stale one explains and cleans up.
- In-app search that is offline and forgiving of case and diacritics.

**Non-Goals:**

- Chapter indexing, remote search, an index extension.

## Decisions

### An indexing seam in Data/Local/Search

`SeriesIndexing` is the data-layer protocol: index items, delete by identifier,
delete all. `SpotlightIndexer` implements it over `CSSearchableIndex.default()`
with domain identifier `dev.opus.readr.series`, swallowing errors — a failed
index write is logged nowhere and surfaced nowhere, per the spec. Tests use a
recording fake.

`SpotlightIdentifier` encodes `SeriesID` as `series|<sourceID>|<url>` and decodes
it back, rejecting anything else. It is the one place that format lives.

`SpotlightAttributes` maps a `Series` (plus its source name and optional
thumbnail bytes) to `CSSearchableItemAttributeSet`: `displayTitle`, source name,
author, genres as keywords, synopsis. Series-level metadata only.

### The library drives the index

`SpotlightLibraryObserver` (Data/Repository) is a `LibraryChangeObserver`: a save
indexes that series at once, without a thumbnail, then fetches the cover through
the shared `HTTPClient` in a detached task and re-indexes with it when the fetch
succeeds; a removal deletes that identifier. Because every metadata write goes
through `LibraryRepository.save` — detail refresh, title repair, Browse add — the
index follows metadata changes without any caller knowing it exists.

It is installed at the composition root beside the download observer.

### A system-search repository resolves and rebuilds

Domain `SystemSearchRepository`, implemented by `DefaultSystemSearchRepository`
over the library and the indexer:

- `resolve(activityIdentifier:)` → `.series(SeriesID)` when it decodes and the
  series is saved; `.noLongerSaved` after deleting the stale entry when it decodes
  but is not saved; `.unrecognized` otherwise.
- `rebuildIndex()` → delete all, then index every saved series. Run at launch and
  from Settings.

### The shell opens results

`RootTabView` handles `onContinueUserActivity(CSSearchableItemActionType)` and
passes the resolution to `NavigationState.open(_:)`, which is plain state and
tested: a series closes any open Reader, selects Library, and sets its path to
that series; a stale result sets a `notice` the shell shows as an alert;
unrecognized does nothing. The app opens without error in every case.

### In-app search is local

`LibrarySearch.matches(_:title:)` (Domain) folds case and diacritics with
`String.folding` and matches the query as a substring of the display title,
ignoring surrounding whitespace. `LibraryModel` applies it after filters and
before sorting. A query with no matches yields a distinct `searchEmpty` phase,
separate from `empty` and `filteredEmpty`. No network is involved.

*Alternative considered — `CSSearchQuery` for in-app search.* Rejected: it is
asynchronous, depends on the index having been built, and would make in-app
search fail exactly when the index is lost — which the spec says must not affect
the library.

## Risks / Trade-offs

- **Launch rebuild cost** → one delete and one batch index over the library; the
  library is personal-scale, and it runs off the main actor.
- **Thumbnails fetched over the network** → best-effort, after the item already
  exists, never blocking the save.
- **Spotlight can be disabled by the user** → index calls then fail silently;
  in-app search is unaffected.

## Migration Plan

No schema change. The index is created at first launch after upgrade. Rollback is
`git revert`; leftover index entries resolve as unrecognized or stale and clean up.

## Open Questions

None.
