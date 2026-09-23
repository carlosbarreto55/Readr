## 1. Domain

- [x] 1.1 Add `Readr/Domain/SystemSearchRepository.swift` and
      `Readr/Domain/Model/LibrarySearch.swift`, covered by
      `ReadrTests/Domain/LibrarySearchTests.swift`

## 2. Search infrastructure

- [x] 2.1 Add `Readr/Data/Local/Search/SpotlightIdentifier.swift`,
      `SpotlightAttributes.swift`, and `SpotlightIndexer.swift` (with the
      `SeriesIndexing` seam), covered by `ReadrTests/Data/SpotlightTests.swift`
- [x] 2.2 Add `Readr/Data/Repository/SpotlightLibraryObserver.swift` and
      `Readr/Data/Repository/DefaultSystemSearchRepository.swift`, covered by
      `ReadrTests/Data/SystemSearchRepositoryTests.swift`
- [x] 2.3 Install the observer, the repository, and the launch rebuild in
      `Readr/Core/DI/AppContainer.swift`

## 3. Presentation

- [x] 3.1 Add Library search in `Readr/UI/Library/`, covered by
      `ReadrTests/UI/LibrarySearchModelTests.swift`
- [x] 3.2 Open Spotlight results through `Readr/UI/Navigation/NavigationState.swift`
      and `RootTabView.swift`, covered by `ReadrTests/UI/NavigationStateTests.swift`
- [x] 3.3 Add Rebuild Spotlight Index to `Readr/UI/Settings/`, covered by
      `ReadrTests/UI/SettingsModelTests.swift`

## 4. Documentation

- [x] 4.1 Update `AGENTS.md`, `README.md`, `architecture.md`, `codemap.md`, and
      the local `codemap.md` files touched above

## 5. Verification

- [x] 5.1 Run XcodeGen, build, tests, bundle check, SwiftLint, swift-format, and
      `openspec validate --all`
- [x] 5.2 Review the diff against the twelve invariants and the four-file rule
- [x] 5.3 Launch the app in the simulator as a smoke test
- [x] 5.4 Archive `add-system-search`
