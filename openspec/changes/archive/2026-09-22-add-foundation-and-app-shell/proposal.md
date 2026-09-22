## Why

Readr currently launches to a single placeholder view. Nineteen capabilities are
specified and none are implemented, because almost all of them sit behind a
foundation that no spec owns: the domain vocabulary, the plugin boundary, the
identifier every stored record is keyed by, and the app shell those capabilities
are presented inside.

This change builds that foundation. Nothing about a site, a screen, or a database
can be written honestly until the contracts they all depend on exist and are
proven.

## What Changes

- The app opens onto its real shell: four tabs — Library, Browse, Downloads,
  Settings — each its own navigation stack. Every tab explains that its feature
  has not been built yet rather than showing an empty screen.
- The vocabulary the whole app speaks — series, chapter, chapter content, a page
  of catalog results, source metadata, catalog filters — exists as framework-free
  immutable values.
- The plugin boundary from `architecture.md` §4.2 exists as a protocol, and
  sources become reachable by identifier through a registry.
- Source identity becomes computable and permanently stable. `computeSourceID`
  is pinned to a specified algorithm and locked by a test asserting a hardcoded
  value, so the identifier half of every stored key can never drift.
- Dependencies are assembled in one place and reach screens through the
  environment, so no view ever constructs its own.
- Typography, spacing, and color live in one place and scale with the reader's
  chosen text size.

No site is contacted. No data is stored. Nothing in this change is **BREAKING** —
there is no released behavior to break.

## Capabilities

### New Capabilities

- `app-shell-navigation`: the tab shell, per-tab navigation paths that survive
  tab switching, routes that carry their own identifiers, and the rule that an
  unbuilt feature states its absence rather than appearing broken

  Two related rules are deliberately **not** in this capability yet. Effect-driven
  navigation stays in `AGENTS.md` until a screen actually emits an effect, and the
  Reader's full-screen presentation is specified by the change that builds the
  Reader. This capability says only that a chapter route is not pushed onto a
  tab's path.

### Modified Capabilities

None. `source-contract` is already normative and this change implements it as
written. Choosing among the hash algorithms it permits is an implementation
decision recorded in `design.md`, not a change to what the capability requires.

## Impact

- **New code**: `Readr/Domain/Model/`, `Readr/Core/Util/`, `Readr/Core/DI/`,
  `Readr/Data/Source/`, `Readr/UI/Theme/`, `Readr/UI/Navigation/`
- **Rewritten**: `Readr/ReadrApp.swift` — its placeholder root is replaced, and
  its doc comment forward-references a change name that was never used
- **New tests**: `ReadrTests/` gains its first cases, including the
  `computeSourceID` guard rail
- **Documentation**: the per-directory `codemap.md` files for every directory
  above stop saying "no implementation yet"
- **Dependencies**: none added. SwiftSoup and Nuke remain declared and unimported.
- **Downstream**: every later change depends on this one. Nothing depends on it
  being revisited.

## Non-goals

- Any site plugin, or any network request whatsoever
- Any persistence — no SwiftData model, no store, no preferences
- Any real screen. The four tabs hold placeholders, not the four-file screen
  pattern, because a placeholder has no state and no model to wire
- Any repository protocol. Contracts arrive with the milestone that implements
  them; a protocol with no consumer is a guess
- The Reader itself. This change reserves how Reader is presented, and builds
  none of it
