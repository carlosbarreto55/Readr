## 1. Comic domain and persistence

- [x] 1.1 Add `case comic = "comic"` to `Readr/Domain/Model/ContentType.swift` and accept `(.pages, .comic)` in `Readr/Domain/Model/ChapterContent.swift`. Add raw-value round-trip and shape-match cases to `ReadrTests/Domain/ChapterContentTests.swift`.
- [x] 1.2 Add `.comic` to the page branches in `Readr/Data/Source/HTMLSource.swift`, `Readr/Data/Repository/ChapterDownloader.swift`, and `Readr/Data/Local/Filesystem/ChapterPayloadStore.swift`. Extend the payload and download tests so a comic issue stores every page locally and reopens offline.
- [x] 1.3 Add `comicPageLayout` (default `.paged`) and its `RawSettingKey` to `Readr/Domain/Model/ReaderPreferences.swift`. Add preference tests for the default, the round-trip, and independence from `pageLayout` and `mangaPageLayout`.

## 2. ReadComicsOnline source

- [x] 2.1 Save live fixtures into `ReadrTests/Fixtures/readcomicsonline/`: `comics.html`, `new-comics.html`, `search-batman.html`, `series-absolute-batman.html`, and `issue-absolute-batman-24.html`. The error path uses inline HTML in the test, as `MangaPillTests` does.
- [x] 2.2 Implement `Readr/Sources/ReadComicsOnline/ReadComicsOnline.swift`: finite `/comics`, `/new-comics`, and `/search?q=` listings; series-only anchor filtering; details; issue chapters with numeric `number`; and `parsePages` that decodes the embedded `pages` payload in `pageNumber` order and throws when it is absent. Selectors must come from the fixtures. Cover listings, the no-next-page case, details, chapters, page order and count, and the missing-payload error in `ReadrTests/Sources/ReadComicsOnlineTests.swift` through `StubURLProtocol`.
- [x] 2.3 Register the source in `Readr/Core/DI/SourceRegistration.swift`, update the registration tests, and add the source row to `Readr/Sources/codemap.md`.

## 3. Reader and app integration

- [x] 3.1 Route layout reads and writes by content type in `Readr/UI/Reader/PageRenderer.swift`, `Readr/UI/Reader/ReaderContent.swift`, and `Readr/UI/Reader/ReaderModel.swift`. Comics use `comicPageLayout` and paged comics render left-to-right. Add `ReadrTests/UI/` coverage for the comic default, switching to vertical without touching the manhwa or manga preferences, and logical-index progress and restoration.
- [x] 3.2 Add a comic layout row in `Readr/UI/Settings/SettingsContent.swift` and `Readr/UI/Settings/SettingsModel.swift`. Replace the content-type label ternaries there and in `Readr/UI/Series/SeriesState.swift` with exhaustive `switch`es that label comics "Comic"/"Comics", and add settings and series-state tests.
- [x] 3.3 Add a "Comics" filter to `Readr/UI/Library/LibraryState.swift`, with filter and persistence tests.

## 4. Verification

- [x] 4.1 Run `openspec validate add-readcomicsonline-comics --strict`.
- [x] 4.2 Run `/verify` (XcodeGen, build, tests, SwiftLint, swift-format) and fix any issues in changed files.
- [ ] 4.3 In the simulator: browse ReadComicsOnline, open Absolute Batman #24 in paged left-to-right, switch to vertical, then download the issue and reopen it offline.
