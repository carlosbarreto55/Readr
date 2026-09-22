## 1. Toolchain baseline

- [ ] 1.1 Point the toolchain at Xcode: `sudo xcode-select -s /Applications/Xcode.app`
      (requires a human; the license is already accepted). **Worked around** for
      now by exporting `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`,
      which needs no `sudo` — but every command in `AGENTS.md` assumes the
      permanent switch, so this stays open
- [x] 1.2 Install `swiftlint` and `swift-format` so `/verify` can complete
- [x] 1.3 Run `xcodegen generate` and build, closing the
      `bootstrap-readr-architecture` tasks 5.2 and 5.3 that were blocked on 1.1
- [x] 1.4 Fix the artifact key in `openspec/config.yaml` — `spec:` to `specs:` —
      so the project's own spec-authoring rules are actually applied

### Discovered while working

- [x] 1.5 `project.yml`: set `GENERATE_INFOPLIST_FILE: YES` on `ReadrTests`. The
      test target had no `Info.plist` and could not be code signed, so it could
      never have run — the defect archived task 5.2 was blocked from finding
- [x] 1.6 Add `.swift-format`: 4-space indentation, and
      `multiElementCollectionTrailingCommas: false` to settle a direct conflict
      between `swift-format` and SwiftLint's `trailing_comma` rule. Both tools are
      mandated, so the conflict is resolved in config once rather than letting
      each reformat the other's output

## 2. Domain vocabulary

Every file in this section lives in `Readr/Domain/Model/` and imports nothing
beyond Foundation.

- [x] 2.1 `ContentType.swift`, `SeriesStatus.swift` — `String`-backed enums with
      explicit raw values. Test in `ReadrTests/Domain/ContentTypeTests.swift`
      asserting the raw values are exactly `"novel"` / `"manhwa"`, because
      `computeSourceID` consumes them
- [x] 2.2 `Series.swift`, `Chapter.swift` — immutable `Sendable` structs keyed by
      `(sourceID, url)` via `SeriesID` / `ChapterID`. Test in
      `ReadrTests/Domain/IdentityTests.swift` that two values sharing that pair
      are equal and that a differing `sourceID` is not
- [x] 2.3 `ChapterContent.swift` — the two-case enum from `architecture.md` §4.2.
      Test in `ReadrTests/Domain/ChapterContentTests.swift` covering both cases
- [x] 2.4 `SeriesPage.swift`, `SourceInfo.swift` — test in
      `ReadrTests/Domain/SeriesPageTests.swift` that an empty page with
      `hasMore == false` is representable, per `source-contract`
- [x] 2.5 `Filter.swift`, `FilterList.swift` — only what the `Source` signature
      forces. Test in `ReadrTests/Domain/FilterListTests.swift`

## 3. Source identity

- [x] 3.1 `Readr/Core/Util/StableHash.swift` — `stableHash64(_:)`, FNV-1a 64, and
      `Readr/Core/Util/ComputeSourceID.swift` — `computeSourceID(name:lang:type:)`
      over `"\(name)/\(lang)/\(type.rawValue)"`, per `design.md`. Split into two
      files as `Core/Util/codemap.md` specifies
- [x] 3.2 `ReadrTests/Core/ComputeSourceIDTests.swift` and
      `ReadrTests/Core/StableHashTests.swift` — the guard rails: hardcoded
      expected values for fixed inputs, cross-checked against an independent
      FNV-1a implementation, plus that distinct inputs differ and that components
      cannot be shifted across the separator. Per `source-contract`, these
      expectations are never updated to match changed output

## 4. Source contract

- [x] 4.1 `Readr/Data/Source/Source.swift` — the protocol transcribed from
      `architecture.md` §4.2, plus the `info` projection repositories hand to
      presentation
- [x] 4.2 `Readr/Data/Source/SourceRegistry.swift` — `[Int64: any Source]` lookup.
      Test in `ReadrTests/Data/SourceRegistryTests.swift` using
      `ReadrTests/Support/StubSource.swift`, covering a hit, a miss, ordering, and
      that a source's identifier is derived rather than hand-picked

## 5. Composition root

- [x] 5.1 `Readr/Core/DI/AppContainer.swift` — owns `URLSession` and the
      `SourceRegistry`, plus its SwiftUI environment entry
- [x] 5.2 `Readr/Core/DI/SourceRegistration.swift` — `liveSources()`, the one
      place concrete site types are imported. Returns nothing yet; the first
      plugin registers here

## 6. Theme

- [x] 6.1 `Readr/UI/Theme/Palette.swift`, `Spacing.swift`, `Typography.swift` —
      semantic colors, the spacing scale, and named fonts built from text styles.
      No fixed point size appears anywhere

## 7. App shell

- [x] 7.1 `Readr/UI/Navigation/Routes.swift` — `AppTab`, one route enum per tab,
      and `ReaderRoute`. Test in `ReadrTests/UI/RouteTests.swift` that routes
      naming the same subject compare equal
- [x] 7.2 `Readr/UI/Navigation/NavigationState.swift` — per-tab paths and the
      selected tab. Test in `ReadrTests/UI/NavigationStateTests.swift` that a push
      on one tab survives switching away and back, and leaves other tabs untouched
- [x] 7.3 `Readr/UI/Navigation/RootTabView.swift` — four tabs, each wrapping its
      own `NavigationStack`, Library selected on launch
- [x] 7.4 `Readr/UI/Navigation/PlaceholderDestination.swift` — the shared
      not-yet-built view, naming its feature and presented as absence rather than
      as an error or an empty result
- [x] 7.5 `Readr/ReadrApp.swift` — build and inject `AppContainer`, swap
      `PlaceholderRootView` for `RootTabView`, and drop the doc comment's forward
      reference to a change name that was never used

## 8. Documentation

- [x] 8.1 Replace the "no implementation yet" banner in the `codemap.md` of every
      directory this change populates, and list what each now holds
- [x] 8.2 Update the root `codemap.md`, `AGENTS.md`, `architecture.md`, and
      `README.md` where each states the repository is a skeleton with one Swift
      file

## 9. Verification

- [x] 9.1 Run the verification sequence — generate, build, test, bundle check,
      lint, format, `openspec validate --all`. 45 tests in 10 suites pass; both
      linters report zero violations; no `.md` ships in the bundle
- [x] 9.2 Prove determinism: `computeSourceID`'s expected values were computed in
      one process, cross-checked against an independent implementation, and are
      asserted by tests running in later, separate processes. A `Hasher`-based
      implementation could not pass
- [x] 9.3 Launch in the simulator: four tabs, Library selected, each placeholder
      naming its feature, verified at the default and at
      `accessibility-extra-extra-large` with no clipping
- [x] 9.4 Run the `reviewer` lane over the diff against the twelve invariants.
      Clean on all twelve. It found that `architecture.md` §4.1 documented the
      hash input as `"\(name)/\(lang)/\(type)"` while the code uses
      `type.rawValue` — byte-identical today, so the guard rail is blind to the
      substitution — and that `name` and `lang` were undeclared persisted format.
      Both are now fixed and recorded. Three spec and proposal overclaims were
      also corrected before archiving made them normative
- [x] 9.5 `openspec archive add-foundation-and-app-shell` so `app-shell-navigation`
      becomes normative
