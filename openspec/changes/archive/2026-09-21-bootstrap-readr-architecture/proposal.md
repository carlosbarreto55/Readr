## Why

Readr replicates the feature set of
[ReaderParser](https://github.com/PedrocaODev/ReaderParser), an Android webnovel
and manhwa reader, as a native iOS app. It is a from-scratch repository, not a
fork.

Starting with code would have meant re-deriving the layer rules, identity
invariants, and persistence boundaries that already exist — and re-deriving them
badly, because several only become visible once something has gone wrong. The
Android app's real asset is its documentation infrastructure: a normative
architecture guide, a descriptive codemap, layered agent rule files, and
per-capability specs. Readr adopts that model first, then builds against it.

This change establishes the repository. It is recorded as archived on arrival:
`repository-governance` requires non-trivial work to begin as an OpenSpec change,
and bootstrapping the repository is the work that requirement first applies to.
Recording it keeps the history honest rather than leaving a governance hole at
the root commit.

## What Changes

- A generated Xcode project skeleton: `project.yml` (XcodeGen), one app target,
  one test target, iOS 26.0, Swift 6 strict concurrency, iPhone only.
- The full directory tree for every architectural layer, each directory carrying
  its own `codemap.md`.
- `architecture.md` — normative layer rules, contracts, and twelve invariants.
- `codemap.md` — the descriptive atlas, plus 28 per-directory maps.
- `AGENTS.md` and four nested rule sheets; `CLAUDE.md` as a thin pointer.
- 19 capability specs under `openspec/specs/`.
- Six agent lanes in `.claude/agents/` and a `/verify` skill.

One Swift file is written: `Readr/ReadrApp.swift`, holding `@main` and a
placeholder root view, so the project compiles and the verification lane is real
from the first commit.

## Capabilities

### New Capabilities

- `repository-governance`: change-management policy and documentation ownership
- `agent-lane-hardening`: scope limits binding each agent lane
- `source-contract`: the plugin boundary, source identity, error propagation
- `source-listing-pagination`: catalog paging behavior
- `source-detail-parsing`: detail fetch and merge semantics
- `source-metadata-cache`: response caching and invalidation
- `source-request-performance`: concurrency, timeouts, off-main parsing
- `library-browse-catalog`: library membership and catalog surfaces
- `library-filtering`: library filter and sort behavior
- `library-search-via-spotlight`: in-app and system search
- `spotlight-indexable-series`: Core Spotlight index as a projection
- `library-blank-title-repair`: recovery for unparsed titles
- `series-catalog-ui`: the shared catalog grid
- `unified-reader-screen`: one Reader, two renderers, shared chrome
- `chapter-refresh-state-preservation`: refresh merge semantics
- `download-enqueue`: queueing and sequential draining
- `download-progress-reporting`: observable queue state
- `download-offline-reader`: serving stored payloads
- `schema-migration`: SwiftData versioning policy

### Modified Capabilities

None — this change creates the repository.

## Impact

Creates the repository. No existing behavior is affected. No feature code is
written; every capability above is specified and unimplemented.

## Non-goals

- Any screen, model, repository, source plugin, or SwiftData entity
- Any test beyond the empty target
- A GitHub remote
- App Store distribution — Readr is personal-use software
