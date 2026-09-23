## 1. Library domain projection

- [x] 1.1 Add immutable `LibraryItem` metadata in
      `Readr/Domain/Model/LibraryItem.swift`, extend
      `Readr/Domain/LibraryRepository.swift`, and cover identity/value behavior
      in `ReadrTests/Domain/LibraryItemTests.swift`
- [x] 1.2 Map existing entity timestamps in
      `Readr/Data/Local/Database/SeriesMapper.swift` and
      `Readr/Data/Repository/SwiftDataLibraryRepository.swift`, with mapper and
      repository coverage in `ReadrTests/Data/MapperTests.swift` and
      `ReadrTests/Data/LibraryRepositoryTests.swift`

## 2. Shared catalog presentation

- [x] 2.1 Select the existing Nuke package's `NukeUI` product in `project.yml`
      and add `Readr/UI/Components/CoverImage.swift`
- [x] 2.2 Add the shared Dynamic-Type-aware card and adaptive grid in
      `Readr/UI/Components/SeriesCard.swift` and
      `Readr/UI/Components/SeriesCatalogGrid.swift`, including stateless
      previews for success, missing-cover, and long-title states

## 3. Library screen

- [x] 3.1 Implement filtering, deterministic sorting, persisted selections,
      optimistic removal, and navigation effects in
      `Readr/UI/Library/LibraryState.swift` and
      `Readr/UI/Library/LibraryModel.swift`, with hand-rolled-fake coverage in
      `ReadrTests/UI/LibraryModelTests.swift`
- [x] 3.2 Implement explicit loading, offline empty, error, filtered-empty, and
      populated states in `Readr/UI/Library/LibraryContent.swift` and wire the
      environment-owned model/effects in `Readr/UI/Library/LibraryScreen.swift`

## 4. Browse screen

- [x] 4.1 Implement source discovery, popular/latest/search request switching,
      `CatalogPager` delegation, retry, paging, optimistic membership, and
      navigation effects in `Readr/UI/Browse/BrowseState.swift` and
      `Readr/UI/Browse/BrowseModel.swift`, with hand-rolled-fake coverage in
      `ReadrTests/UI/BrowseModelTests.swift`
- [x] 4.2 Implement the source list and explicit catalog loading/empty/error/grid
      states in `Readr/UI/Browse/BrowseContent.swift` and wire the
      environment-owned model/effects in `Readr/UI/Browse/BrowseScreen.swift`

## 5. Navigation and documentation

- [x] 5.1 Replace Library/Browse placeholders and install typed catalog/series
      destinations in `Readr/UI/Navigation/RootTabView.swift`, extending
      `ReadrTests/UI/NavigationStateTests.swift` where route behavior changes
- [x] 5.2 Update `AGENTS.md`, `README.md`, `architecture.md`, root and local
      `codemap.md` files, and `project.yml` comments to describe the shipped M5
      surfaces and remaining M6–M9 boundaries

## 6. Verification

- [x] 6.1 Run XcodeGen, generic simulator build, the iPhone 17 test suite, bundle
      markdown check, SwiftLint, swift-format, and strict OpenSpec validation
- [x] 6.2 Run the `reviewer` lane against the twelve invariants, M5 specs,
      Dynamic Type behavior, and the four-file screen rule
- [ ] 6.3 Archive `add-catalog-ui`
