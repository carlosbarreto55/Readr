## 1. Domain

- [x] 1.1 Add `LibraryChapter` in `Readr/Domain/Model/LibraryChapter.swift` and
      `ChapterReadingOrder` in `Readr/Domain/Model/ChapterReadingOrder.swift`,
      covered by `ReadrTests/Domain/ChapterReadingOrderTests.swift`
- [x] 1.2 Add `Series.displayTitle` in `Readr/Domain/Model/Series+DisplayTitle.swift`,
      covered by `ReadrTests/Domain/SeriesDisplayTitleTests.swift`
- [x] 1.3 Extend `Readr/Domain/LibraryRepository.swift` with
      `libraryChapters(for:)`, `mergeChapterList(_:for:)`, `setRead(_:isRead:in:)`,
      and `emptyChapterList`; add `Readr/Domain/SeriesRepository.swift` with
      `SeriesSnapshot` and `LibraryRefreshReport`; add `knownSeries(_:)` to
      `Readr/Domain/CatalogRepository.swift`

## 2. Persistence

- [x] 2.1 Freeze v1 models inside `Readr/Data/Local/Database/SchemaV1.swift`, add
      `Readr/Data/Local/Database/SchemaV2.swift` with the lightweight stage, and
      point `SeriesEntity.swift` / `ChapterEntity.swift` at v2
- [x] 2.2 Map the new fields in `Readr/Data/Local/Database/ChapterMapper.swift`
- [x] 2.3 Prove v1 → v2 on disk in `ReadrTests/Data/StoreSurvivalTests.swift`

## 3. Repositories

- [x] 3.1 Implement the merge, reading-order read, and read-state writes in
      `Readr/Data/Repository/SwiftDataLibraryRepository.swift`, covered by
      `ReadrTests/Data/ChapterMergeTests.swift`
- [x] 3.2 Remember listing entries in
      `Readr/Data/Repository/DefaultCatalogRepository.swift`, covered by
      `ReadrTests/Data/CatalogRepositoryTests.swift`
- [x] 3.3 Implement `Readr/Data/Repository/DefaultSeriesRepository.swift`
      (stored, seed, refresh, library refresh with blank-title repair), covered by
      `ReadrTests/Data/SeriesRepositoryTests.swift`
- [x] 3.4 Build the series repository in `Readr/Core/DI/AppContainer.swift`

## 4. Series screen

- [x] 4.1 Implement `Readr/UI/Series/SeriesState.swift` and
      `Readr/UI/Series/SeriesModel.swift`, covered by
      `ReadrTests/UI/SeriesModelTests.swift`
- [x] 4.2 Implement `Readr/UI/Series/SeriesContent.swift` with previews and
      `Readr/UI/Series/SeriesScreen.swift`
- [x] 4.3 Route every `.series` destination to `SeriesScreen` and add the
      throttled activation refresh in `Readr/UI/Navigation/RootTabView.swift`
- [x] 4.4 Use `displayTitle` in `Readr/UI/Components/SeriesCard.swift` and
      Library's title sort; add `.refreshable` library refresh in
      `Readr/UI/Library/`, covered by `ReadrTests/UI/LibraryModelTests.swift`

## 5. Documentation

- [x] 5.1 Update `AGENTS.md`, `README.md`, `architecture.md`, `codemap.md`, and
      the local `codemap.md` files touched above

## 6. Verification

- [x] 6.1 Run XcodeGen, build, tests, bundle check, SwiftLint, swift-format, and
      `openspec validate --all`
- [x] 6.2 Review the diff against the twelve invariants and the four-file rule
- [x] 6.3 Archive `add-series-detail`
