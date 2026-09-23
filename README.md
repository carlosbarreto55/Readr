# Readr

A personal-use iOS app that unifies webnovel and manhwa reading across multiple
sites. Each site is a **source plugin** behind a common protocol — the rest of the
app doesn't know or care which site it's talking to.

> Personal project. Not for distribution. Not affiliated with any site this app
> reads from.

---

## Status

**Library, Browse, Series detail, the Reader, Downloads, and Settings are now
functional.** The framework-free
domain, stable source identity, composition root, versioned SwiftData library,
preferences, bounded source runtime, cache, and pager are implemented and tested.
FreeWebNovel and AsuraScans provide fixture-tested novel and manhwa catalogs.
Their results appear through a shared adaptive grid; readers can browse popular
and latest releases, search, page, add/remove library membership, and filter or
sort the offline library with selections restored after relaunch. A series opens
from stored state offline, refreshes its chapters without losing reading state,
and a library refresh repairs series saved with a blank title. Chapters open in
one Reader — native text for novels, a vertical or paged image run for manhwa —
that records and restores reading progress and follows the reader's theme, font,
and text size. Chapters queue for offline reading, download one at a time,
survive relaunch, and read without a network; the library refreshes in the
background when iOS allows it.

Spotlight integration remains to be built.

---

## Credit

Readr is a ground-up iOS reimplementation of
[**ReaderParser**](https://github.com/PedrocaODev/ReaderParser) by
[@PedrocaODev](https://github.com/PedrocaODev) — an Android app with the same
purpose, written in Kotlin and Jetpack Compose.

This is **not a fork.** No code is shared, and the two repositories have no common
history. What Readr does inherit is ReaderParser's architecture: the `Source`
plugin boundary, the layered dependency rules, the identity and persistence
invariants, and — just as deliberately — its documentation model for AI coding
agents.

What Readr does *not* inherit is the interface. The UI is designed for iOS rather
than translated from Compose. `architecture.md` §9 records where that divergence
is architectural rather than cosmetic.

---

## What it will do

- Browse and search across configured sites (popular, latest, full-text search).
- Add series to a local library.
- Read novels and manhwa in one reader with content-appropriate renderers.
- Download chapters for offline reading.
- Track reading progress per chapter.
- Surface the library in system search via Spotlight.
- Refresh the library in the background to surface new chapters.

---

## Tech stack

| Concern | Choice |
| --- | --- |
| UI | SwiftUI |
| Async / state | Swift Concurrency, `@Observable` |
| HTTP | `URLSession` |
| HTML parsing | SwiftSoup |
| JSON | `Codable` |
| Database | SwiftData |
| Preferences | `UserDefaults` behind `SettingsStore` |
| Images | Nuke through NukeUI |
| Background | `BGTaskScheduler`, background `URLSession` |
| DI | `AppContainer` composition root |
| System search | Core Spotlight |
| Deployment target | iOS 26.0 |
| Language | Swift 6, strict concurrency |
| Devices | iPhone |

---

## Documentation

| File | What's in it |
| --- | --- |
| [`architecture.md`](architecture.md) | Layers, contracts, invariants, decisions |
| [`codemap.md`](codemap.md) | Repository structure, entry points, directory maps |
| [`AGENTS.md`](AGENTS.md) | Rules for AI coding agents (and humans, honestly) |
| [`CLAUDE.md`](CLAUDE.md) | Claude Code specifics; defers to `AGENTS.md` |
| `openspec/specs/` | Per-capability normative specs |

Read `architecture.md` first if you're reasoning about anything beyond a single
file. The other docs assume you've seen it.

---

## Setup

Requires Xcode 27+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
open Readr.xcodeproj
```

`Readr.xcodeproj` is **generated and gitignored** — `project.yml` is the source of
truth. Run `xcodegen generate` after cloning and after any change to `project.yml`.
Never edit the `.pbxproj`.

---

## Verification

```bash
xcodegen generate
xcodebuild -scheme Readr -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme Readr -destination 'platform=iOS Simulator,name=iPhone 17' test
swiftlint
swift-format lint --recursive Readr ReadrTests
openspec validate --all
```

There's a `/verify` skill that runs the whole sequence.

---

## Adding a new source

1. Create `Readr/Sources/<SiteName>/<SiteName>.swift`.
2. Extend `HTMLSource`. Implement chapter text **or** chapter pages — never both.
3. Register it in `Readr/Core/DI/SourceRegistration.swift`.
4. Add HTML fixtures under `ReadrTests/Fixtures/<sitename>/`.
5. Add a test that drives the fixtures through a stubbed `URLProtocol`.

Full rules in [`Readr/Sources/AGENTS.md`](Readr/Sources/AGENTS.md). The
`source-author` agent scaffolds all five steps but will not invent CSS selectors,
by design — a guessed selector produces a source that fails silently.

---

## Working with agents

This repo is set up for Claude Code:

- [`AGENTS.md`](AGENTS.md) — non-negotiables and routing
- `Readr/**/AGENTS.md` — narrower rules close to the code
- `.claude/agents/` — specialized lanes (`source-author`, `screen-author`,
  `schema-migration`, `domain-author`, `runner`, `reviewer`)
- `.claude/commands/opsx/` — OpenSpec workflow: `/opsx:explore`,
  `/opsx:propose`, `/opsx:update`, `/opsx:apply`, `/opsx:archive`, `/opsx:sync`
- `.claude/skills/verify/` — `/verify`, the full verification sequence

Non-trivial changes follow the OpenSpec workflow: propose → design → specs →
tasks → implement. See [`AGENTS.md`](AGENTS.md) and
`openspec/specs/repository-governance/spec.md`.

---

## License

MIT — see [`LICENSE`](LICENSE).
