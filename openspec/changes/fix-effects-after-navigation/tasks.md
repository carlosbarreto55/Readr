## 1. Fix

- [x] 1.1 Add `Readr/Core/Util/EffectChannel.swift`, covered by
      `ReadrTests/Core/EffectChannelTests.swift`
- [x] 1.2 Publish effects through it in `Readr/UI/Browse/BrowseModel.swift`,
      `Readr/UI/Library/LibraryModel.swift`, `Readr/UI/Series/SeriesModel.swift`,
      `Readr/UI/Reader/ReaderModel.swift`, and
      `Readr/UI/Downloads/DownloadsModel.swift`, with regression tests in
      `ReadrTests/UI/BrowseModelTests.swift` and
      `ReadrTests/UI/LibraryModelTests.swift`
- [x] 1.3 Update `Readr/Core/Util/codemap.md`

## 2. Verification

- [x] 2.1 Run XcodeGen, build, tests, SwiftLint, swift-format, and
      `openspec validate --all`
- [ ] 2.2 Install on the device and confirm navigation after returning
- [ ] 2.3 Archive `fix-effects-after-navigation`
