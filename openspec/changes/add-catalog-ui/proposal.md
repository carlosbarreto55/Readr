## Why

Readr can discover real sources and persist a library, but both catalog tabs are
still placeholders. M5 connects those existing capabilities so a reader can
browse, search, save, filter, sort, and reopen series through the app shell.

## What Changes

- Replace the Library placeholder with an offline-first adaptive series grid,
  explicit loading/empty/error/filter-empty states, and context-menu removal.
- Replace the Browse placeholder with source discovery, popular/latest catalogs,
  search, pagination, retry, and immediate add/remove library actions.
- Give both surfaces the same Dynamic-Type-aware card/grid components, resilient
  cover loading, source labels, context menus, and typed series-detail routing.
- Persist and restore Library content-type/source filters and title/date-added/
  last-read sorting, including deterministic placement of unread series.
- Expose saved-series timestamps as immutable domain data so presentation can
  sort without importing SwiftData types.
- Add model, component, repository, navigation, and persistence tests using
  hand-rolled fakes or in-memory stores.

## Capabilities

### New Capabilities

None. This change implements the already-normative catalog capabilities.

### Modified Capabilities

- `library-browse-catalog`: make the Browse surface's registered-source
  selection, popular/latest modes, and submitted text search explicit. Existing
  membership, grid, and state requirements are unchanged.

## Impact

- **UI:** `Readr/UI/Library/`, `Readr/UI/Browse/`, shared catalog components,
  and the Library/Browse destinations in `RootTabView`.
- **Domain:** an immutable saved-library item carrying its `Series`, date added,
  and last-read timestamp; `LibraryRepository` exposes those items without
  leaking persistence types.
- **Data:** `SwiftDataLibraryRepository` maps existing schema-v1 metadata into
  the new domain value. No schema migration or identity change is needed.
- **Images:** the existing Nuke package is consumed through its `NukeUI` product;
  no dependency is added.
- **Navigation:** card taps emit typed `.series` routes. M6 replaces the existing
  placeholder destination with the full detail screen.
- **Downloads:** removal continues to delete membership and chapter state. The
  downloaded-payload part of the existing removal requirement remains staged to
  M8, when download storage first exists.

## Non-goals

- Series detail and chapter-list UI (M6), reader rendering (M7), or downloads
  and their payload deletion (M8).
- Remote genre/status filters; the initial sources truthfully advertise none.
- A new schema version, source-protocol change, dependency, app target, or
  entitlement.
