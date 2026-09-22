## 1. Project skeleton

- [x] 1.1 Install XcodeGen and write `project.yml` — app target, test target,
      iOS 26.0, Swift 6 strict concurrency, iPhone only, `dev.opus.readr`
- [x] 1.2 Declare SwiftSoup and Nuke as package dependencies, imported by nothing
- [x] 1.3 Exclude `**/*.md` from target sources so per-folder docs never ship
- [x] 1.4 Create the full layer directory tree
- [x] 1.5 Write `Readr/ReadrApp.swift` — `@main` plus a placeholder root view
- [x] 1.6 Add the asset catalog and register the `BGTaskScheduler` identifiers
- [x] 1.7 `.gitignore` the generated `.xcodeproj`; add the MIT `LICENSE`

## 2. Architecture

- [x] 2.1 Write `architecture.md`: purpose, principles, layer model, contracts
- [x] 2.2 Document the twelve invariants, including stable `sourceID` hashing and
      the `@Model`/domain split
- [x] 2.3 Document persistence ownership and download storage location
- [x] 2.4 Document decisions and trade-offs, including best-effort background work
- [x] 2.5 Write the interface-adaptation section recording iOS divergences

## 3. Agent infrastructure

- [x] 3.1 Write root `AGENTS.md` — non-negotiables, paths, placement, gates,
      commit conventions
- [x] 3.2 Write `CLAUDE.md` as a thin pointer at `AGENTS.md`
- [x] 3.3 Write four nested `AGENTS.md` rule sheets
- [x] 3.4 Write `codemap.md` and 28 per-directory maps
- [x] 3.5 Write six agent lanes in `.claude/agents/`
- [x] 3.6 Write the `/verify` skill
- [x] 3.7 Add the documentation CI workflow

## 4. Specs

- [x] 4.1 `openspec init` and write the Readr project context into `config.yaml`
- [x] 4.2 Write the governance and agent specs
- [x] 4.3 Write the five source-plugin specs
- [x] 4.4 Write the six library specs
- [x] 4.5 Write the two reader specs
- [x] 4.6 Write the three download specs
- [x] 4.7 Write the schema-migration spec
- [x] 4.8 `openspec validate --all` passes

## 5. Verification

- [x] 5.1 `xcodegen generate` succeeds
- [ ] 5.2 `xcodebuild build` succeeds — blocked on Xcode license acceptance
- [ ] 5.3 No `.md` file appears in the built `.app` — blocked on 5.2
- [x] 5.4 Every documentation cross-reference resolves
