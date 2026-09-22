# AGENTS.md

Readr is a personal iOS app that reads webnovel and manhwa sites through
site-specific `Source` plugins. UI is SwiftUI; persistence is SwiftData;
networking is `URLSession` + SwiftSoup.

Use this file for repo-specific rules and routing only.

- Read `architecture.md` for layer rules, contracts, invariants, and
  architectural decisions.
- Read `codemap.md` for repository structure, entry points, and directory maps.
- Read a folder's `codemap.md` for local implementation details inside that area.

> **The repository is a skeleton.** `Readr/ReadrApp.swift` is the only Swift file.
> Every directory below exists and is documented, but empty. The specs in
> `openspec/specs/` define what goes in them.

## Non-negotiables

1. Domain code has **zero** SwiftUI, SwiftData, `URLSession`, or SwiftSoup imports.
2. Network calls live only inside `Source` implementations or repositories.
3. Presentation models never reference `SourceRegistry` or a concrete `Source`.
4. One Reader screen with content-specific renderers for text and image pages.
5. `ChapterContent` stays an enum with exactly `.text(html:)` and `.pages(imageURLs:)`.
6. Domain models are immutable `struct`s conforming to `Sendable`.
7. No blocking waits on the main actor; no `DispatchSemaphore` in production code.
8. `*Screen` wires the model; `*Content` is the stateless `#Preview` target.
9. Series/chapter identity is `(sourceID, url)`.
10. Downloads stay in Application Support, excluded from iCloud backup.
11. `sourceID` uses an explicitly stable hash — **never** Swift's `Hasher`.
12. SwiftData `@Model` classes are persistence types, never domain types.

Rules 11 and 12 are the two easiest to violate by accident and the two most
expensive to discover late. `architecture.md` §4.1 and §6.1 explain why.

## Important paths

Main code lives under `Readr/`.

| Area | Path |
| --- | --- |
| Domain models | `Readr/Domain/Model/` |
| Repository protocols | `Readr/Domain/` |
| Repository implementations | `Readr/Data/Repository/` |
| Source contract / base types | `Readr/Data/Source/` |
| SwiftData models, mappers, migrations | `Readr/Data/Local/Database/` |
| Download storage | `Readr/Data/Local/Filesystem/` |
| Preferences | `Readr/Data/Local/Prefs/` |
| Spotlight indexing | `Readr/Data/Local/Search/` |
| Composition root | `Readr/Core/DI/` |
| Shared utilities | `Readr/Core/Util/` |
| Site plugins | `Readr/Sources/` |
| Screens, navigation, theme | `Readr/UI/` |
| Background tasks | `Readr/Background/` |
| Tests and fixtures | `ReadrTests/` |

## Read the nearest local rules

- `Readr/UI/AGENTS.md` for SwiftUI screens.
- `Readr/Sources/AGENTS.md` for new source plugins.
- `Readr/Data/Source/AGENTS.md` for the `Source` contract.
- `Readr/Data/Local/Database/AGENTS.md` for SwiftData changes.

## Project specialists

- `source-author` — new site plugins + fixtures/tests.
- `screen-author` — four-file SwiftUI screen scaffolding.
- `schema-migration` — SwiftData schema versions + migration tests.
- `domain-author` — domain models and repository protocols.
- `runner` — build, test, lint, format verification.
- `reviewer` — read-only diff review against the invariants above.

Prefer these specialists over stuffing repo-specific workflow into the root
prompt.

## Placement rules

- New source: `Readr/Sources/<SiteName>/<SiteName>.swift`
- Repository: `Readr/Domain/` protocol + `Readr/Data/Repository/` implementation
- SwiftData models / mappers / migrations: `Readr/Data/Local/Database/`
- Reusable views: `Readr/UI/Components/`
- New screen: `Readr/UI/<Screen>/` with exactly `<Name>Screen.swift`,
  `<Name>Content.swift`, `<Name>Model.swift`, `<Name>State.swift`

### The four-file screen pattern

| File | Contains |
| --- | --- |
| `<Name>Screen.swift` | Reads `AppContainer` from the environment, owns the model, handles `Effect`s and navigation. No `#Preview`. |
| `<Name>Content.swift` | Stateless `View`. Pure function of `<Name>State` plus an `onAction` closure. Always has a `#Preview`. |
| `<Name>Model.swift` | `@Observable @MainActor final class <Name>Model`. Exposes `state` and `onAction(_:)`. Takes repositories via `init`. |
| `<Name>State.swift` | `<Name>State` struct, `<Name>Action` enum, `<Name>Effect` enum. |

Navigation travels through `Effect`, never through state.

## Testing and verification

New code ships with tests.

- Sources: unit tests with saved HTML fixtures and a stubbed `URLProtocol`
- Repositories / models: unit tests with hand-rolled fakes
- SwiftData changes: migration tests
- `computeSourceID`: a test asserting a hardcoded expected value — never update
  it to match changed output

Fixtures live in `ReadrTests/Fixtures/<sitename>/`.

Verification commands:

```bash
xcodegen generate
xcodebuild -scheme Readr -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme Readr -destination 'platform=iOS Simulator,name=iPhone 17' test
swiftlint
swift-format lint --recursive Readr ReadrTests
```

The `/verify` skill runs the whole sequence, plus a check that no `.md` file
shipped inside the app bundle. Do not silence lint or test failures to get green.

Xcode must be selected and licensed before any of this works:

```bash
sudo xcode-select -s /Applications/Xcode.app
sudo xcodebuild -license accept
```

## Tooling

- `Readr.xcodeproj` is **generated and gitignored**. Edit `project.yml` and run
  `xcodegen generate`. Never edit the `.pbxproj`.
- Use `git` for local history; `gh` for PRs, issues, and workflow runs.
- `openspec` (1.6+) drives the change workflow.

## Ask before doing

Ask before:

- changing the `Source` protocol
- changing `@Model` identity, primary keys, or relationship delete rules
- adding a new top-level layer or target
- changing target structure in `project.yml`
- adding an entitlement or an `Info.plist` capability
- adding a third-party dependency
- changing `computeSourceID`'s algorithm

Routine work — a new source, screen, repository method, or migration — proceeds
without a separate approval gate.

## Change workflow

Non-trivial work starts as an OpenSpec change: propose → design → specs → tasks →
implement. See `openspec/specs/repository-governance/spec.md` for the policy and
the exhaustive list of trivial exemptions.

Commands, generated by the OpenSpec CLI into `.claude/commands/opsx/`:

| Command | Use |
| --- | --- |
| `/opsx:explore` | Investigate before proposing |
| `/opsx:propose` | Create a change with proposal, design, specs, and tasks |
| `/opsx:update` | Revise an existing change's artifacts |
| `/opsx:apply` | Work the change's task list |
| `/opsx:archive` | Fold a completed change into `openspec/specs/` |
| `/opsx:sync` | Reconcile specs with the current changes |

These files are generated. Do not hand-edit them — `openspec update` overwrites
them.

## Commit conventions

Every commit uses one of the prefixes below. A commit never mixes prefixes.

| Prefix | When to use |
| --- | --- |
| `feat:` | New file, new screen, new source plugin, new capability |
| `fix:` | Bug fix to previously committed code |
| `refactor:` | Restructuring committed code without changing behavior |
| `ci:` | CI pipeline, hooks, verification scripts, `project.yml` build settings |
| `cd:` | Release pipeline, signing config, deployment scripts |
| `docs:` | `AGENTS.md`, `architecture.md`, `codemap.md`, `README.md`, `openspec/` |
