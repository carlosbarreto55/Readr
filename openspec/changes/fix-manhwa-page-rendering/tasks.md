## 1. Fix

- [x] 1.1 Rework `Readr/UI/Reader/PageRenderer.swift`: observed position,
      one-shot restore, remembered aspect ratios, display-width requests, one
      prefetcher, labelled loading placeholder
- [x] 1.2 Skip unchanged positions in `Readr/UI/Reader/ReaderModel.swift`,
      covered by `ReadrTests/UI/ReaderModelTests.swift`
- [x] 1.3 Update `Readr/UI/Reader/codemap.md`

## 2. Verification

- [x] 2.1 Run XcodeGen, build, tests, SwiftLint, swift-format, and
      `openspec validate --all`
- [ ] 2.2 Install on the device and confirm on a real AsuraScans chapter
- [ ] 2.3 Archive `fix-manhwa-page-rendering`
