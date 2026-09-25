## 1. Manga domain and persistence

- [x] 1.1 Add `.manga` and page-shape matching in `Readr/Domain/Model/ContentType.swift`, `ChapterContent.swift`, and `ReadrTests/Domain/ChapterContentTests.swift`.
- [x] 1.2 Handle manga in `Readr/Data/Source/HTMLSource.swift`, `Readr/Data/Repository/ChapterDownloader.swift`, `Readr/Data/Local/Filesystem/ChapterPayloadStore.swift`, and matching source/download/payload tests.

## 2. MangaPill source and images

- [x] 2.1 Implement `Readr/Sources/MangaPill/MangaPill.swift` and saved `ReadrTests/Fixtures/mangapill/` fixtures, with `ReadrTests/Sources/MangaPillTests.swift` covering listings, pagination, details, chapters, and page URLs through stubbed `URLProtocol`.
- [x] 2.2 Register the source in `Readr/Core/DI/SourceRegistration.swift` and update registration tests.
- [x] 2.3 Add a scoped MangaPill image header rule to the Nuke pipeline in `Readr/Core/DI/` and test that it applies to MangaPill images but not unrelated hosts.

## 3. Reader and app integration

- [x] 3.1 Add a separate persisted manga page layout to `Readr/Domain/Model/ReaderPreferences.swift`, `Readr/UI/Settings/`, `Readr/UI/Reader/`, and preference/model tests.
- [x] 3.2 Make `Readr/UI/Reader/PageRenderer.swift` render paged manga right-to-left with logical-index progress and restoration; add focused `ReadrTests/UI/` coverage.
- [x] 3.3 Add manga to `Readr/UI/Library/LibraryState.swift` and source type labels in `Readr/UI/Settings/SettingsContent.swift`, with filter/settings tests.

## 4. Verification

- [x] 4.1 Run OpenSpec validation, XcodeGen, build, tests, SwiftLint, and swift-format; fix any issues in changed files.
