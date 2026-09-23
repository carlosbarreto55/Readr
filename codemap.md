# Repository Atlas: Readr

This document is the **descriptive repository atlas**. It owns current structure,
entry points, directory responsibilities, and implementation locations. Use
`architecture.md` for normative layer rules, contracts, invariants, and
architectural decisions.

> **Foundation through catalog UI.** `Domain/`, `Core/`,
> `Data/Source/`, `Data/Local/Database/`, `Data/Local/Prefs/`, `Data/Repository/`,
> `Sources/`, `UI/Theme/`, `UI/Navigation/`, `UI/Components/`, `UI/Library/`,
> and `UI/Browse/` are implemented and tested. Remaining feature directories
> below exist, are documented, and are empty. Each directory's
> `codemap.md` states what it is *for*; `openspec/specs/` states how it must
> *behave*.
>
> The runtime a site plugin needs now exists — fetching, parsing, caching, paging,
> and the detail merge — and `liveSources()` registers FreeWebNovel and
> AsuraScans. Library and Browse consume only repository/domain contracts; the
> next unimplemented destination is series detail in M6.

## Project Responsibility

Readr is a single-target iOS application for reading webnovel and manhwa content
from site-specific source plugins behind a common `Source` protocol. The
repository is organised around a strict layered architecture: SwiftUI screens and
`@Observable` models consume framework-free domain protocols, repository
implementations bridge those protocols to SwiftData / filesystem / `UserDefaults`
persistence, and source plugins use `URLSession` + SwiftSoup to fetch and parse
remote content.

## Root Assets

| Path | Role |
| --- | --- |
| `AGENTS.md` | Repository operating rules and doc-routing policy for coding agents. |
| `CLAUDE.md` | Claude Code specifics only; defers to `AGENTS.md`. |
| `architecture.md` | Normative architecture guide: layer rules, contracts, invariants, decisions. |
| `codemap.md` | This file — the descriptive atlas. |
| `README.md` | Human-facing overview and attribution. |
| `project.yml` | **Source of truth for the Xcode project.** `Readr.xcodeproj` is generated and gitignored. |
| `Readr/` | Application source root. |
| `ReadrTests/` | Unit test target and HTML fixtures. |
| `openspec/` | Normative per-capability specs and the change workflow. |
| `.claude/agents/` | Six specialized agent lanes. |
| `.claude/commands/opsx/` | OpenSpec workflow commands — **generated**, do not hand-edit. |
| `.claude/skills/` | OpenSpec skills (generated) plus Readr's own `verify`. |
| `.github/workflows/` | CI. |

## System Entry Points

| Path | Responsibility |
| --- | --- |
| `Readr/ReadrApp.swift` | `@main`. Builds `AppContainer` and injects it into the SwiftUI environment. The only file permitted to construct the object graph. |
| `Readr/Core/DI/` | Composition root: `ModelContainer`, `URLSession`, `SourceRegistry`, repositories. |
| `Readr/UI/Navigation/` | Tab shell and typed navigation paths. |
| `Readr/Domain/` | Repository protocols and pure domain types consumed by presentation. |
| `Readr/Data/Repository/` | Concrete repositories that orchestrate sources and persistence. |
| `Readr/Data/Source/Source.swift` | The stable plugin protocol implemented by each site. |
| `Readr/Background/` | `BGTaskScheduler` entry points for refresh and download processing. |

## Architecture Snapshot

*Non-normative summary for orientation. `architecture.md` is authoritative for
every rule below; where the two disagree, `architecture.md` wins.*

- **Presentation model:** each screen is four files — `Screen` + `Content` + `Model` + `State`.
- **State management:** `@Observable @MainActor` models expose `state`, an `Effect` stream, and `onAction(_:)`.
- **Domain boundary:** `Domain/` is framework-free — immutable `Sendable` structs and protocols only.
- **Data orchestration:** `Data/Repository/` is the only layer allowed to coordinate `SourceRegistry` and local storage.
- **Plugin model:** site integrations live under `Sources/`, extending `HTMLSource`.
- **Persistence split:** SwiftData for structured metadata and progress, `UserDefaults` for settings, filesystem for downloaded payloads.
- **Unified reader:** one Reader screen renders both content shapes through dedicated renderers.
- **Identity rule:** series and chapters are identified by `(sourceID, url)`, where `sourceID` comes from a stable non-`Hasher` hash.

## Primary Runtime Flow

1. `ReadrApp` builds `AppContainer` and injects it into the environment.
2. `AppShell` presents the tab shell; each tab owns a `NavigationStack`.
3. Screens delegate user actions to their `@Observable` model.
4. Models call domain repository protocols.
5. Repositories read and write SwiftData / `UserDefaults` / filesystem, and call `SourceRegistry[sourceID]` when remote data is needed.
6. Source plugins fetch and parse site content into domain models.
7. State flows back to SwiftUI through the observed model; navigation and alerts travel as `Effect`s.
8. Background tasks reuse the same repository/source/storage graph outside the UI lifecycle.

## Repository Directory Map

| Directory | Responsibility Summary | Detailed Map |
| --- | --- | --- |
| `Readr/` | Application source root | [`Readr/codemap.md`](Readr/codemap.md) |
| `Readr/Core/` | Composition root and utilities | [`Readr/Core/codemap.md`](Readr/Core/codemap.md) |
| `Readr/Core/DI/` | `AppContainer`, source registration | [`Readr/Core/DI/codemap.md`](Readr/Core/DI/codemap.md) |
| `Readr/Core/Util/` | Stable hashing, source ID, title matching | [`Readr/Core/Util/codemap.md`](Readr/Core/Util/codemap.md) |
| `Readr/Domain/` | Repository protocols | [`Readr/Domain/codemap.md`](Readr/Domain/codemap.md) |
| `Readr/Domain/Model/` | Immutable domain types | [`Readr/Domain/Model/codemap.md`](Readr/Domain/Model/codemap.md) |
| `Readr/Data/` | Repositories, persistence, plugin contract | [`Readr/Data/codemap.md`](Readr/Data/codemap.md) |
| `Readr/Data/Repository/` | Repository implementations | [`Readr/Data/Repository/codemap.md`](Readr/Data/Repository/codemap.md) |
| `Readr/Data/Source/` | `Source`, `HTMLSource`, `SourceRegistry` | [`Readr/Data/Source/codemap.md`](Readr/Data/Source/codemap.md) |
| `Readr/Data/Local/` | Local persistence, split by concern | [`Readr/Data/Local/codemap.md`](Readr/Data/Local/codemap.md) |
| `Readr/Data/Local/Database/` | SwiftData models, mappers, migrations | [`Readr/Data/Local/Database/codemap.md`](Readr/Data/Local/Database/codemap.md) |
| `Readr/Data/Local/Filesystem/` | Downloaded payload storage | [`Readr/Data/Local/Filesystem/codemap.md`](Readr/Data/Local/Filesystem/codemap.md) |
| `Readr/Data/Local/Prefs/` | `UserDefaults` settings | [`Readr/Data/Local/Prefs/codemap.md`](Readr/Data/Local/Prefs/codemap.md) |
| `Readr/Data/Local/Search/` | Core Spotlight indexing | [`Readr/Data/Local/Search/codemap.md`](Readr/Data/Local/Search/codemap.md) |
| `Readr/Sources/` | Site plugins | [`Readr/Sources/codemap.md`](Readr/Sources/codemap.md) |
| `Readr/UI/` | Screens, navigation, theme | [`Readr/UI/codemap.md`](Readr/UI/codemap.md) |
| `Readr/UI/Navigation/` | Tab shell, typed routes | [`Readr/UI/Navigation/codemap.md`](Readr/UI/Navigation/codemap.md) |
| `Readr/UI/Library/` | Saved series | [`Readr/UI/Library/codemap.md`](Readr/UI/Library/codemap.md) |
| `Readr/UI/Browse/` | Source catalogs | [`Readr/UI/Browse/codemap.md`](Readr/UI/Browse/codemap.md) |
| `Readr/UI/Series/` | Series detail | [`Readr/UI/Series/codemap.md`](Readr/UI/Series/codemap.md) |
| `Readr/UI/Reader/` | Unified reader | [`Readr/UI/Reader/codemap.md`](Readr/UI/Reader/codemap.md) |
| `Readr/UI/Downloads/` | Queue and stored chapters | [`Readr/UI/Downloads/codemap.md`](Readr/UI/Downloads/codemap.md) |
| `Readr/UI/Settings/` | Preferences | [`Readr/UI/Settings/codemap.md`](Readr/UI/Settings/codemap.md) |
| `Readr/UI/Components/` | Shared views | [`Readr/UI/Components/codemap.md`](Readr/UI/Components/codemap.md) |
| `Readr/UI/Theme/` | Colors, spacing, typography | [`Readr/UI/Theme/codemap.md`](Readr/UI/Theme/codemap.md) |
| `Readr/Background/` | `BGTaskScheduler` entry points | [`Readr/Background/codemap.md`](Readr/Background/codemap.md) |
| `Readr/Resources/` | Assets and generated `Info.plist` | [`Readr/Resources/codemap.md`](Readr/Resources/codemap.md) |
| `ReadrTests/` | Tests and HTML fixtures | [`ReadrTests/codemap.md`](ReadrTests/codemap.md) |

## Local Rules

Four directories carry their own `AGENTS.md`. Read the nearest one before editing
inside it:

| Path | Covers |
| --- | --- |
| [`Readr/UI/AGENTS.md`](Readr/UI/AGENTS.md) | The four-file screen pattern and UI constraints |
| [`Readr/Sources/AGENTS.md`](Readr/Sources/AGENTS.md) | Adding a site plugin |
| [`Readr/Data/Source/AGENTS.md`](Readr/Data/Source/AGENTS.md) | The `Source` contract and source IDs |
| [`Readr/Data/Local/Database/AGENTS.md`](Readr/Data/Local/Database/AGENTS.md) | SwiftData schema and migrations |
