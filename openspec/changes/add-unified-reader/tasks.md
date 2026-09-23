## 1. Domain

- [x] 1.1 Add reader preference values and keys in
      `Readr/Domain/Model/ReaderPreferences.swift`, covered by
      `ReadrTests/Domain/ReaderPreferencesTests.swift`
- [x] 1.2 Add `Readr/Domain/ChapterRepository.swift`; add
      `recordProgress` to `Readr/Domain/LibraryRepository.swift` and
      `chapterContent(for:)` to `Readr/Domain/CatalogRepository.swift`

## 2. Data and parsing

- [x] 2.1 Record progress in
      `Readr/Data/Repository/SwiftDataLibraryRepository.swift`, covered by
      `ReadrTests/Data/ReadingProgressTests.swift`
- [x] 2.2 Fetch content in `Readr/Data/Repository/DefaultCatalogRepository.swift`
- [x] 2.3 Implement `Readr/Data/Repository/DefaultChapterRepository.swift`,
      covered by `ReadrTests/Data/ChapterRepositoryTests.swift`
- [x] 2.4 Add `Readr/Core/Util/ChapterTextParser.swift`, covered by
      `ReadrTests/Core/ChapterTextParserTests.swift`
- [x] 2.5 Build the chapter repository in `Readr/Core/DI/AppContainer.swift`

## 3. Reader screen

- [x] 3.1 Implement `Readr/UI/Reader/ReaderState.swift` and
      `Readr/UI/Reader/ReaderModel.swift`, covered by
      `ReadrTests/UI/ReaderModelTests.swift`
- [x] 3.2 Implement `Readr/UI/Reader/TextRenderer.swift`,
      `Readr/UI/Reader/PageRenderer.swift`, `Readr/UI/Reader/ReaderContent.swift`
      with previews, `Readr/UI/Reader/ReaderScreen.swift`, and
      `Readr/UI/Theme/ReaderColors.swift`
- [x] 3.3 Present the Reader from `Readr/UI/Navigation/RootTabView.swift` via
      `Readr/UI/Navigation/NavigationState.swift`; open it from
      `Readr/UI/Series/SeriesScreen.swift` and reload read state on close

## 4. Settings screen

- [x] 4.1 Implement `Readr/UI/Settings/` (four files), covered by
      `ReadrTests/UI/SettingsModelTests.swift`, and replace the Settings
      placeholder in `Readr/UI/Navigation/RootTabView.swift`

## 5. Documentation

- [x] 5.1 Update `AGENTS.md`, `README.md`, `architecture.md`, `codemap.md`, and
      the local `codemap.md` files touched above

## 6. Verification

- [x] 6.1 Run XcodeGen, build, tests, bundle check, SwiftLint, swift-format, and
      `openspec validate --all`
- [x] 6.2 Review the diff against the twelve invariants and the four-file rule
- [ ] 6.3 Archive `add-unified-reader`
