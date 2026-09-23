## 1. Domain

- [x] 1.1 Add download values in `Readr/Domain/Model/Download.swift`, covered by
      `ReadrTests/Domain/DownloadTests.swift`
- [x] 1.2 Add `Readr/Domain/DownloadRepository.swift`; add `series(_:contentType:)`
      to `Readr/Domain/ChapterRepository.swift`

## 2. Persistence and storage

- [x] 2.1 Add `Readr/Data/Local/Database/SchemaV3.swift` with `DownloadEntity`
      and `DownloadMapper.swift`; extend `ReadrMigrationPlan.swift`; prove v2 → v3
      in `ReadrTests/Data/StoreSurvivalTests.swift`
- [x] 2.2 Add `Readr/Data/Local/Filesystem/ChapterPayloadStore.swift`, covered by
      `ReadrTests/Data/ChapterPayloadStoreTests.swift`

## 3. Repositories

- [x] 3.1 Implement `Readr/Data/Repository/DefaultDownloadRepository.swift` and
      `Readr/Data/Repository/DownloadTransport.swift`, covered by
      `ReadrTests/Data/DownloadRepositoryTests.swift`
- [x] 3.2 Prefer stored payloads in
      `Readr/Data/Repository/DefaultChapterRepository.swift`, covered by
      `ReadrTests/Data/ChapterRepositoryTests.swift`
- [x] 3.3 Add `Readr/Data/Repository/ObservedLibraryRepository.swift` and wire
      removal cleanup and launch resume in `Readr/Core/DI/AppContainer.swift`,
      covered by `ReadrTests/Data/ObservedLibraryRepositoryTests.swift`

## 4. Screens

- [x] 4.1 Implement `Readr/UI/Downloads/` (four files), covered by
      `ReadrTests/UI/DownloadsModelTests.swift`; replace the placeholder in
      `Readr/UI/Navigation/RootTabView.swift` and delete
      `Readr/UI/Navigation/PlaceholderDestination.swift`
- [x] 4.2 Add download state and actions to `Readr/UI/Series/`, covered by
      `ReadrTests/UI/SeriesModelTests.swift`
- [x] 4.3 Add the download control to `Readr/UI/Reader/`, covered by
      `ReadrTests/UI/ReaderModelTests.swift`
- [x] 4.4 Add storage to `Readr/UI/Settings/`, covered by
      `ReadrTests/UI/SettingsModelTests.swift`

## 5. Background

- [x] 5.1 Add `Readr/Background/BackgroundTasks.swift`; register it from
      `Readr/ReadrApp.swift` and schedule on backgrounding from
      `Readr/UI/Navigation/RootTabView.swift`

## 6. Documentation

- [x] 6.1 Update `AGENTS.md`, `README.md`, `architecture.md` (§8 background
      execution), `codemap.md`, and the local `codemap.md` files touched above

## 7. Verification

- [x] 7.1 Run XcodeGen, build, tests, bundle check, SwiftLint, swift-format, and
      `openspec validate --all`
- [x] 7.2 Review the diff against the twelve invariants and the four-file rule
- [ ] 7.3 Archive `add-downloads`
