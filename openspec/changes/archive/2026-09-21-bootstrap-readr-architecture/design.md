## Context

ReaderParser is a single-module Android app: Compose, Room, Ktor, Jsoup,
WorkManager, Hilt, with a `Source` plugin boundary and a documentation set built
for AI coding agents. Readr targets iPhone on iOS 26 with SwiftUI and SwiftData.

The architectural boundaries transfer cleanly. The interface does not, and is not
meant to.

## Goals / Non-Goals

**Goals:**

- Preserve the plugin boundary, layer rules, and identity invariants that make the
  original tractable
- Adapt the interface to iOS rather than translate Compose layouts
- Adopt the documentation model — normative architecture, descriptive codemap,
  layered agent rules, per-capability specs
- Reach a state where implementation is mechanical

**Non-Goals:**

- Sharing code or history with ReaderParser
- Matching its interface
- App Store distribution

## Decisions

**SwiftData over GRDB or Core Data.** Apple-native, the closest ergonomic
counterpart to Room, and `VersionedSchema` plus `SchemaMigrationPlan` is a real
migration story. Coarser than Room's, so `schema-migration` is written as its own
normative spec rather than left to prose.

**No DI framework.** `AppContainer` is a composition root injected through the
SwiftUI `Environment`; models take repositories via `init`. A Hilt equivalent
would buy nothing at this size and would make the object graph harder to read.

**XcodeGen over a committed project file.** A `.pbxproj` is unreadable in review,
conflicts constantly, and is a poor thing to ask an agent to edit. `project.yml`
is 100 reviewable lines, and `excludes: ["**/*.md"]` keeps the per-folder docs out
of the app bundle in one line.

**Native text rendering over a web view.** The domain still carries HTML, but
`.text(html:)` renders as `AttributedString` in a native view. A web view would
port faster and read worse: no Dynamic Type, no system typography, no reader
themes, awkward selection.

**Core Spotlight replaces Samsung Search.** Same idea — make the library findable
from the OS — so the requirements port almost verbatim.

**Two invariants added that the original does not need.** `sourceID` must use an
explicitly stable hash, because Swift's `Hasher` is seeded per process and would
orphan the library on every launch. SwiftData `@Model` classes must stay out of
the domain, because the macro requires reference types and context binding.

**Specs written before code, all nineteen at once.** The capability set is known —
it is the feature set of a working app. Writing them together surfaces the
contradictions between them now rather than one sprint at a time.

## Risks / Trade-offs

**Specs may not survive contact with implementation.** Nineteen specs written
against an unimplemented app will contain wrong assumptions. Mitigation: they are
normative, not immutable — the OpenSpec workflow exists to change them, and a spec
that turns out wrong is a change proposal, not a violation.

**Background execution is weaker than WorkManager.** `BGTaskScheduler` offers no
delivery guarantee. Accepted and documented: background refresh is an
optimization, the foreground refresh on activation is the guarantee, and no
feature may assume a background task ran.

**Nuke is a dependency where `AsyncImage` is built in.** Justified by webtoon page
runs needing bounded memory and prefetch; confined to the page renderer and the
cover component.

**Documentation can drift from an empty tree.** Twenty-eight codemaps describing
directories with no code will rot if implementation diverges. Mitigation: each
carries an explicit "no implementation yet" banner, and `repository-governance`
makes updating them part of the change that adds the code.
