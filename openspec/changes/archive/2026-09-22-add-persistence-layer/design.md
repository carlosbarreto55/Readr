## Context

The foundation change built the domain vocabulary, the `Source` contract, and the
app shell. Nothing is stored. This change adds the persistence half of the app:
the SwiftData store, the preferences store, and the first repository behind which
both hide.

`architecture.md` §6 already fixes the boundaries — SwiftData for structured
state, the filesystem for downloaded payloads, `UserDefaults` behind
`SettingsStore`, and `@Model` classes that never cross the repository boundary
(invariant 12). What needs deciding is the shape of the stored data, which is the
most expensive thing in the app to change later.

Sequencing: this is M2 of the nine milestones listed under Migration Plan in
`openspec/changes/archive/2026-09-22-add-foundation-and-app-shell/design.md`.

## Goals / Non-Goals

**Goals**

- A saved series survives relaunch, with no network, with its metadata intact.
- Chapter state follows `(sourceID, url)`, so renumbering cannot move it.
- The store is versioned from its first release, and the harness a future
  migration test needs exists before there is a migration to test.
- No `@Model` type is visible from `Readr/Domain/` or from any repository
  signature.

**Non-Goals**

- Any screen, any network call, the download queue — see the proposal's
  Non-goals.
- Repository protocols beyond `LibraryRepository` and `SettingsStore`.

## Decisions

The first four were put to a human before any schema was written, per the
approval gate in `AGENTS.md` § Ask before doing. All four are **approved**.

### Entity identity is a derived unique key — approved

SwiftData has no composite unique constraint, but domain identity is
`(sourceID, url)` (invariant 9). Each entity therefore stores `sourceID` and `url`
separately for querying, plus a derived `key` marked `@Attribute(.unique)`:

```
key = "\(sourceID)|\(url.absoluteString)"
```

`key` is derived on write and never set by hand.

*Alternative considered — let the repository enforce uniqueness by fetching before
inserting.* More flexible, and one missed call site silently creates a second row
for a series the reader already has, which surfaces as a duplicate card rather
than as an error. Putting the constraint in the store makes invariant 9
enforceable rather than conventional.

*Alternative considered — `@Attribute(.unique)` on `url` alone.* Simpler, and it
asserts that two sources can never publish the same URL string, which nothing
guarantees and which contradicts the identity rule outright.

### The series–chapter relationship cascades — approved

`SeriesEntity.chapters` carries `@Relationship(deleteRule: .cascade)`. Removing a
series deletes its chapters and their read state, which is what
`library-browse-catalog` requires.

*Alternative considered — `.nullify`.* Chapters would outlive their series as
orphans with no way to reach or collect them.

*Alternative considered — `.deny`.* Removal becomes a two-step operation every
call site has to get right.

Downloaded payload deletion is the other half of that requirement and has no
storage to delete yet. It is wired into the same call in M8, and `tasks.md`
records it so it cannot be quietly dropped.

### Download path keys are hex of `stableHash64` — approved

`architecture.md` §6.3 fixes the layout as
`Downloads/<sourceID>/<seriesKey>/<chapterKey>/`, and a URL is not filesystem
safe. `seriesKey` and `chapterKey` are the 16-character hex of
`stableHash64(url.absoluteString)` — fixed length, safe on every filesystem, no
path-length risk, and reusing the function M1 already ships and guard-rails.

Not reversible, which is fine: the store is the index from a path back to a
chapter, not the other way round.

Note this is a *different* key from the database's unique `key`. The database key
is the full string because a collision there would merge two series; a path key is
hashed because it has to be short and safe. Both are derived from the same
`(sourceID, url)`.

*Alternative considered — percent-encoding.* Reversible and readable, but long
URLs can exceed path limits and encoding rules vary enough across platforms to be
a quiet portability risk.

### Read state lives on the chapter — approved

`isRead`, `readingPosition`, and `lastReadAt` are properties of `ChapterEntity`.
Progress has no meaning without its chapter, cascade delete collects it for free,
and refresh merging reads and writes one row.

*Alternative considered — a separate progress entity.* Warranted if progress ever
needs its own lifecycle, such as per-device sync. Nothing in the specs asks for
that, and it would add a join and a second delete rule today.

### The download queue is not in schema v1

Its shape is not known until downloads are designed. Guessing it in now and
reshaping it later is worse than adding it as `SchemaV2` with a migration stage —
and that makes M8 the first genuine exercise of the migration plan, with a real
migration test rather than a synthetic one.

### Library membership is presence, not a flag

A `SeriesEntity` exists only for a series the reader saved. Browse results are not
persisted, so there is no unsaved row needing a flag to hide it. `dateAdded` and
`lastReadAt` are stored because `library-filtering` sorts on them.

### Mappers are free functions, not entity methods

Entity-to-domain conversion lives beside the entities but not on them. A method on
`@Model` would tempt callers to reach for it from outside the repository, which is
exactly the boundary invariant 12 exists to hold.

## Risks / Trade-offs

- **A migration is written wrong and data is lost** → destructive migration is
  forbidden; a container that fails to open surfaces the failure and leaves the
  store intact. The store-survival harness lands with this change so the first
  real migration has a test to extend rather than a test to invent.
- **`@Model` types leak upward** → they are `internal` and confined to
  `Data/Local/Database/`; every repository signature names domain structs only,
  and the `reviewer` lane checks it.
- **The unique `key` is derived, so a wrong derivation corrupts identity** →
  derived in exactly one place, and covered by a round-trip test.
- **`ModelContainer` construction can fail at launch** → it is surfaced rather
  than swallowed. The app is personal-use, so failing visibly beats silently
  starting with an empty library, which is the failure shape §4.1 warns about.

## Migration Plan

No released schema exists, so `SchemaV1` is the baseline and the migration plan
holds no stages yet. Its value is that it exists: the container is opened through
a `SchemaMigrationPlan` from the first release, so adding `SchemaV2` in M8 is a
stage rather than a rewrite.

Rollback is `git revert`. No user data exists to strand.

## Open Questions

- Whether chapter list ordering needs an explicit stored index, or whether source
  order plus `number` is enough. M6 refreshes chapter lists and will answer it.
  Until it does, `LibraryRepository.chapters(for:)` states plainly that order is
  not part of its contract — SwiftData's to-many relationship carries no ordering
  guarantee, so promising one would be a guarantee M6 could not rely on.

## Resolved During Implementation

- **`AppContainer`'s environment default.** Carried over from M1 as "decide when
  the first screen reads a repository, in M5". Answered here instead, because the
  repository landing is what makes the failure concrete: the entry became
  `AppContainer?` with no default, so a view that misses the injection has no
  value to read rather than an empty library to render. See task 4.1.
- **Reader state is stored but not yet reachable.** `ChapterEntity.isRead`,
  `.readingPosition`, `.lastReadAt`, and `SeriesEntity.lastReadAt` are persisted
  and survive a round trip, but no `LibraryRepository` method reads or writes
  them, so the preservation guarantee in `save` and `storeChapters` is verified
  at the mapper level rather than through the repository. That is the correct M2
  boundary — a method with no caller is the speculation task 3.2 refuses — but it
  means M6 must add the accessors *and* the repository-level test that sets read
  state, refreshes, and asserts it survived. Recorded in `tasks.md` §3.
