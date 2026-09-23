## Context

M1–M4 established the domain vocabulary, schema-v1 library, settings store,
source runtime, two live plugins, repositories, and four-tab shell. Library and
Browse are still placeholders. The persisted `SeriesEntity` already owns
`dateAdded` and `lastReadAt`, but `LibraryRepository.savedSeries()` discards both,
so the presentation layer cannot implement two of the three required sorts
without crossing the SwiftData boundary.

This change spans the domain/data boundary, two four-file screens, shared SwiftUI
components, settings, paging, and typed navigation. Existing specs are
authoritative; the change introduces no new capability contract.

## Goals / Non-Goals

**Goals:**

- Make Library fully usable offline from saved metadata.
- Make Browse expose source selection, popular/latest catalogs, search, paging,
  retry, and library membership actions.
- Share one adaptive, accessible grid/card implementation between both screens.
- Persist Library filters and sorting, including date-added and last-read sorts.
- Keep UI models behind domain repositories and navigation behind effects.
- Test repository mapping and model behavior without live networking.

**Non-Goals:**

- The M6 detail/chapter screen, M7 reader, or M8 download subsystem.
- Remote filters not advertised by the source contract.
- Schema, stored identity, source-protocol, target, or entitlement changes.

## Decisions

### Expose saved metadata as a domain value

Add immutable `LibraryItem: Sendable, Identifiable, Hashable`, containing a
`Series`, `dateAdded`, and optional `lastReadAt`. Add `savedItems()` to
`LibraryRepository` while retaining `savedSeries()` for focused callers and
backward compatibility. `SwiftDataLibraryRepository` maps `SeriesEntity` to the
new value inside its model actor; an entity never leaves `Data/`.

The schema already stores both timestamps, so this is a boundary projection, not
a migration. `dateAdded` remains ordered newest-first at the repository boundary;
the Library model applies the user's selected order.

*Alternative considered — fetch `SeriesEntity` in the screen.* Rejected because
it violates the persistence boundary and makes previews/model tests require
SwiftData.

*Alternative considered — add dates to `Series`.* Rejected because those are
reader-library metadata, not facts published by a source. A remote catalog
series has no meaningful date-added value.

### Persist stable filter representations

Library presentation defines `LibraryContentFilter` and `LibrarySort` as
string-backed enums. `RawSettingKey` stores those values. The optional selected
source identifier is stored as a namespaced decimal string, with an empty string
meaning all sources; an unreadable or unavailable source falls back to all.

Filters operate over the in-memory `[LibraryItem]` and never mutate membership.
Title sorts ascending; date-added and last-read sorts descending. Unread items
sort after every read item, with title and identity tie-breakers for deterministic
output.

*Alternative considered — store `Int64` directly.* Rejected because `Int64` is
not a supported `SettingValue`, and broadening the settings contract for one
choice adds no user value.

### Keep screen state renderable and navigation effect-only

`LibraryScreen` and `BrowseScreen` each use exactly Screen, Content, Model, and
State files. Screens read `AppContainer` from the environment, lazily own their
`@Observable @MainActor` model once dependencies are available, forward actions,
and consume an `AsyncStream` of effects. Content views are stateless functions of
state and an action closure and own all previews.

Library effects open a series route. Browse effects open either a source catalog
or a series route. No navigation flag is stored in state, and neither model sees
`NavigationState`, `SourceRegistry`, or a concrete source.

*Alternative considered — pass the container into content or let models look it
up globally.* Rejected because it would erase the testable repository boundary.

### Use one Browse screen for source selection and a source catalog

`BrowseScreen(sourceID: nil)` renders the source list. Selecting a source pushes
`.catalog(sourceID:)`; the destination uses `BrowseScreen(sourceID:)` to render
that source's catalog. This preserves one four-file feature rather than creating
a nearly duplicate catalog screen.

Within a catalog, a presentation request value distinguishes popular, latest,
and submitted search. Switching popular/latest or submitting search constructs a
fresh `CatalogPager`; load-more and retry delegate to that tested state machine.
The model copies pager state into renderable Browse state after each operation.

*Alternative considered — make BrowseModel implement page indexes and duplicate
suppression.* Rejected because `CatalogPager` already owns and tests those
invariants.

### Share adaptive cards and make cover failure explicit

`SeriesCatalogGrid` uses `LazyVGrid` with one adaptive column definition. Its
minimum card width is an `@ScaledMetric`, so larger accessibility sizes naturally
reduce column count; titles use semantic fonts, wrap to a bounded line count, and
grow vertically. Stable series identity drives both `ForEach` and an explicit
scroll-position binding, retaining the first visible series while the grid
reflows on rotation.

`SeriesCard` renders `CoverImage`, title, and source name. `CoverImage` consumes
the existing Nuke dependency through `NukeUI.LazyImage`; missing, loading, and
failed images render the same labeled placeholder while title text remains
outside the image. The card provides tap and context-menu actions supplied by the
surface. No persistent add/remove control is placed on the card.

*Alternative considered — `AsyncImage`.* Rejected because Nuke is already the
project's declared image pipeline and provides the cache/decoding behavior the
architecture selected.

### Treat membership writes as optimistic, recoverable state changes

Browse loads the saved identity set once alongside a catalog. Add/remove updates
the visible card immediately, persists through `LibraryRepository`, and rolls
back with a visible error if the write fails. Library removal similarly removes
the item immediately and restores/reloads on failure. This meets the immediate
feedback requirement without hiding persistence errors.

The repository currently removes membership and cascading chapter state.
Downloaded payload deletion cannot be wired until M8 creates download storage;
the implementation keeps the existing explicit note at that boundary.

### Route now; render full details in M6

Card taps append the existing typed `.series(SeriesID)` route through an effect.
M5 supplies a clearly labeled temporary destination for that route so navigation
is real and testable; M6 replaces only the destination body with the four-file
detail screen. Series data itself is not embedded in the route and cannot become
stale.

## Risks / Trade-offs

- **A saved source is no longer registered** → show a stable fallback source
  label derived from its identifier and reset a persisted unavailable source
  filter to All rather than hiding the library.
- **A paging action races a catalog-mode change** → construct a new pager per
  request and accept results only for the currently active request token.
- **Optimistic membership persistence fails** → roll back the identity/item and
  show an actionable error; never pretend the write succeeded.
- **Large accessibility sizes make cards very wide** → the scaled adaptive
  minimum intentionally reduces columns, preserving readable wrapping.
- **A cover URL fails repeatedly** → NukeUI shows the local placeholder; catalog
  data and interaction remain available.
- **M5 cannot delete nonexistent download payloads** → keep the gap documented
  and complete that clause when M8 introduces the download repository/storage.

## Migration Plan

No data migration is required. Existing settings keys are new and resolve to All
content, All sources, and Date Added before being written. Rollback restores the
two tab placeholders and removes the UI settings keys; schema-v1 library rows and
their timestamps remain unchanged.

## Open Questions

None. The existing specs, repositories, navigation routes, and M6/M8 milestone
boundaries determine the staged behavior.
