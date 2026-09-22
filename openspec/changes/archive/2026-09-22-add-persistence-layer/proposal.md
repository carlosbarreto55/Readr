## Why

Readr forgets everything the moment it closes. The foundation change built the
vocabulary and the shell, but nothing is written down: there is no store, no
preferences, and no repository behind which either could hide.

Every capability that follows needs this. A library that does not survive
relaunch is not a library, and the offline reading the app exists for cannot be
built on top of nothing.

## What Changes

- A series the reader saves stays saved. It survives relaunch, and it survives
  relaunch with no network — the stored copy is enough to display it.
- Chapter read state and reading position are recorded per chapter, keyed to the
  chapter itself rather than to its position in a list, so a source that
  renumbers or reorders its chapters cannot move a reader's progress onto the
  wrong one.
- Removing a series removes what belongs to it.
- The reader's own choices — filters, sort order, reader settings — persist as
  preferences, and a preference that has never been set reads as a documented
  default rather than as nothing.
- The store is versioned from its first release, so the first schema change is a
  migration rather than a data loss.

Nothing here is visible on screen yet: no tab gains a feature in this change. The
persistence is proved by tests rather than by the UI.

## Capabilities

### New Capabilities

- `preferences-store`: what is stored as a preference, how an unset or unreadable
  preference resolves, and the rule that the domain never sees `UserDefaults`

### Modified Capabilities

None. `schema-migration` is already normative and this change implements it as
written, establishing the versioned schema and the migration plan its
requirements govern.

## Impact

- **New code**: `Readr/Data/Local/Database/`, `Readr/Data/Local/Prefs/`,
  `Readr/Data/Repository/`, plus the first repository protocols in
  `Readr/Domain/`
- **Changed**: `Readr/Core/DI/AppContainer.swift` gains the `ModelContainer` and
  the repositories
- **New tests**: mapper round trips, repository behavior against an in-memory
  store, preference defaults, and the store-survival harness every future
  migration test extends
- **Dependencies**: none added. SwiftData is a system framework.
- **Risk**: this change fixes the shape of stored data. Getting entity identity or
  a delete rule wrong here is expensive to correct later, which is why both are
  put up for approval in `design.md` before any schema is written.

## Non-goals

- Any screen. The tabs keep their placeholders; this change ships no UI.
- The download queue. Its shape is not known until downloads are designed, and
  guessing it into the first schema then reshaping it is worse than adding it as
  a second version.
- Any network call, any source plugin, any Spotlight index.
- Repository protocols beyond the ones this change implements.
