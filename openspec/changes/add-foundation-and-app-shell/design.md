## Context

`Readr/ReadrApp.swift` is the only Swift file in the repository. `architecture.md`
already fixes the layer model, the twelve invariants, and the exact shape of the
`Source` protocol (§4.2), so this change is largely transcription and wiring
rather than design. The parts that genuinely need deciding are the source-ID hash
algorithm, how routes are typed, and how much contract surface to build before
there is a consumer for it.

Constraints in force: Swift 6 with `SWIFT_STRICT_CONCURRENCY=complete`, iOS 26.0
deployment target, iPhone only, single Xcode target with layer boundaries enforced
by review rather than by the compiler.

## Goals / Non-Goals

**Goals**

- Every type named in the `Source` protocol exists, is `Sendable`, and imports no
  framework.
- `computeSourceID` is deterministic across launches, devices, and reinstalls, and
  a test makes drift impossible to land accidentally.
- The app launches into its real shell, so later milestones add features rather
  than restructure the root.

**Non-Goals**

- Any network call, any persistence, any real screen — see the proposal's
  Non-goals.
- Designing the `Source` protocol. It is specified in `architecture.md` §4.2 and
  changing it is an approval gate; this change transcribes it.

## Decisions

### `computeSourceID` uses FNV-1a 64

`architecture.md` §4.1 permits FNV-1a 64 or the leading 8 bytes of SHA-256.
**FNV-1a 64 is chosen**: offset basis `14695981039346656037`, prime
`1099511628211`, folded over the UTF-8 bytes of `"\(name)/\(lang)/\(type.rawValue)"`,
with the result reinterpreted as `Int64` by bit pattern.

*Alternative considered — SHA-256 prefix.* Cryptographically stronger, and the
strength buys nothing here: the input space is a handful of developer-authored
source names, and the property required is determinism, not collision resistance
against an adversary. It also pulls in CryptoKit for one call. FNV-1a is six lines
that a reviewer can verify by eye, which matters more for a value that can never
change.

### The hashed input uses explicit raw values, never enum case names

This is the decision most likely to be undone by accident later. The `type`
component MUST contribute `contentType.rawValue`, so `ContentType` and any other
enum feeding the hash carry explicit `String` raw values that are declared to be
frozen.

Interpolating the enum case itself would compile, pass every test on the day it
was written, and silently re-key the entire library the first time somebody
renamed a case. That is the exact failure invariant 11 exists to prevent, reached
through a door the invariant's wording does not cover.

The guard-rail test asserts a hardcoded expected value for a known input. Per
`source-contract`, it is never updated to match changed output.

It has a blind spot worth naming: `"\(type)"` and `"\(type.rawValue)"` produce
identical bytes today, so a contributor who substituted one for the other would
pass every test in the repository, and the damage would surface only at the next
case rename. The defence is that the formula is written with `.rawValue` in
`architecture.md` §4.1 and here, and that the raw values are declared frozen.

The same hazard applies to `name` and `lang`, which are persisted format rather
than display strings, and which `computeSourceID`'s own test cannot pin because
each plugin derives its `id` from its own strings. Recorded in §4.1: a shipped
source's `name` and `lang` are frozen, and every plugin ships a test asserting its
own hardcoded `id`. That test belongs to the source template, so it lands with the
first plugin.

### Routes are per-destination enums, not a shared type

Each top-level destination gets its own `Hashable` route enum and its own path.
A single app-wide route type would let any destination push any other, which is
how a tab shell degrades into implicit global navigation.

Route cases carry `(sourceID, url)` directly rather than a whole `Series`, so a
route stays cheap to compare and cannot go stale against refreshed metadata.

### `AppContainer` is a final class reaching views through the environment

Built once in `ReadrApp`, injected as an environment value. At this milestone it
owns a `URLSession` and the `SourceRegistry`; the `ModelContainer` and
repositories join it in the next change. Views never construct dependencies —
models receive them through `init`, which is what makes models testable with
hand-rolled fakes and no container.

### Repository protocols are deferred

No repository protocol is written here. A protocol with no implementation and no
caller is a guess about a milestone that has not been designed, and it would have
to be rewritten by the change that finally uses it. Each repository contract
lands with the change that implements it.

### Placeholders are plain views, not four-file screens

The four-file pattern exists to separate state, rendering, and wiring. A
placeholder has no state to separate. Introducing empty `Model` and `State` files
for four tabs would create eight files whose only content is ceremony, and every
one would be deleted by the milestone that builds the real screen.

## Risks / Trade-offs

- **A future contributor "simplifies" `computeSourceID`** → the guard-rail test
  fails loudly with a hardcoded value, and both `source-contract` and `AGENTS.md`
  state that the implementation is corrected rather than the expectation updated.
- **Layer rules are not compiler-enforced in a single target** → the `reviewer`
  lane checks the diff against the twelve invariants; this is the accepted
  trade-off already recorded in `architecture.md` §8.
- **The domain model set is built before its consumers exist**, so a field may
  prove wrong at M3 → the set is deliberately limited to what the `Source`
  protocol signature forces, which `architecture.md` §4.2 already fixes. Anything
  not named there waits.
- **Nothing can be built until `xcode-select` points at Xcode** → a one-time
  `sudo` step outside this change's control; `/verify` already documents it.

## Migration Plan

No data exists, so there is nothing to migrate. What this section records instead
is **sequencing** — the milestone order this change is the first step of. Each
later change references its predecessor here rather than duplicating the list.

| # | Change | Implements |
| --- | --- | --- |
| **M1** | `add-foundation-and-app-shell` *(this change)* | `source-contract`, new `app-shell-navigation` |
| M2 | `add-persistence-layer` | `schema-migration`, new `preferences-store` |
| M3 | source runtime | `source-listing-pagination`, `source-detail-parsing`, `source-metadata-cache`, `source-request-performance` |
| M4 | first site plugin, ported from ReaderParser | exercises M3 |
| M5 | catalog UI | `series-catalog-ui`, `library-browse-catalog`, `library-filtering` |
| M6 | series detail | `chapter-refresh-state-preservation`, `library-blank-title-repair` |
| M7 | reader | `unified-reader-screen` |
| M8 | downloads | `download-enqueue`, `download-progress-reporting`, `download-offline-reader` |
| M9 | system search | `spotlight-indexable-series`, `library-search-via-spotlight` |

`repository-governance` and `agent-lane-hardening` are process capabilities already
satisfied by `AGENTS.md` and `.claude/agents/`. They are enforced by the `reviewer`
lane and are never implemented as code.

Rollback is `git revert`; nothing outside the repository is touched.

## Open Questions

- Which sources M4 ports first, and whether ReaderParser's saved fixtures are
  still current against the live sites. Does not block M1.
- Whether `Filter`/`FilterList` need more than the minimum the `Source` signature
  forces. Deferred to M3, where the first real catalog reveals the answer.
- **The environment's default `AppContainer` is empty rather than absent.** That is
  harmless while the container holds only a `URLSession` and an empty registry:
  previews and tests get a usable value and nothing can fail. Once repositories
  join it in M2, a view that misses the injection would show an empty library
  instead of failing — the same silent-empty shape §4.1 warns about, from a
  different cause. Revisit when the first repository lands.
