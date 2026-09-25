## 1. Domain

- [x] 1.1 Rewrite `continueTarget(in:)` in `Readr/Domain/Model/ChapterReadingOrder.swift` to anchor on the most recently read engaged chapter, with the untimestamped fallback; cover it in `ReadrTests/Domain/ChapterReadingOrderTests.swift`
- [x] 1.2 Add `recordOpened(_:at:)` to `Readr/Domain/LibraryRepository.swift` and `recordOpened(in:)` to `Readr/Domain/ChapterRepository.swift`

## 2. Data

- [x] 2.1 Implement `recordOpened` in `Readr/Data/Repository/SwiftDataLibraryRepository.swift`, forward it in `ObservedLibraryRepository.swift`, and wrap it in `DefaultChapterRepository.swift`; test in `ReadrTests/Data/ReadingProgressTests.swift`
- [x] 2.2 Add `recordOpened` to test fakes (`ReadrTests/Support/InMemoryLibraryRepository.swift`, `ReadrTests/UI/BrowseModelTestSupport.swift`, `ReadrTests/UI/LibraryModelTests.swift`, `ReadrTests/UI/ReaderModelTests.swift`)

## 3. Reader

- [x] 3.1 In `Readr/UI/Reader/ReaderModel.swift`, record an open instead of progress on load, and gate progress writes on moving 5% from the opening position or reaching the end; cover it in `ReadrTests/UI/ReaderModelTests.swift`

## 4. Verify

- [x] 4.1 Run `/verify` and `openspec validate fix-continue-reading-target`
