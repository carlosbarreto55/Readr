## 1. Fixture support

- [x] 1.1 Add a fixture loader to `ReadrTests/Support/FixtureLoader.swift` and
      cover missing fixture failures in `ReadrTests/Support/FixtureLoaderTests.swift`

## 2. FreeWebNovel

- [x] 2.1 Add live-backed HTML extracts under
      `ReadrTests/Fixtures/freewebnovel/` and implement
      `Readr/Sources/FreeWebNovel/FreeWebNovel.swift` with its fixture-driven
      tests in `ReadrTests/Sources/FreeWebNovelTests.swift`
- [x] 2.2 In `ReadrTests/Sources/FreeWebNovelTests.swift`, pin the plugin's
      hardcoded ID and cover popular/latest/search URLs, details, chapters,
      cleaned text content, pagination, and malformed required markup

## 3. AsuraScans

- [x] 3.1 Add honestly attributed, hand-reduced extracts of directly observed
      HTML under `ReadrTests/Fixtures/asurascans/` and
      implement `Readr/Sources/AsuraScans/AsuraScans.swift` with its
      fixture-driven tests in `ReadrTests/Sources/AsuraScansTests.swift`
- [x] 3.2 In `ReadrTests/Sources/AsuraScansTests.swift`, pin the plugin's
      hardcoded ID and cover request headers, browse/latest/search URLs, details,
      chapters and dates, ordered page content, finite latest pagination, and
      malformed required markup

## 4. Composition and documentation

- [x] 4.1 Register both plugins in `Readr/Core/DI/SourceRegistration.swift` and
      prove discovery through `ReadrTests/Data/CatalogRepositoryTests.swift`
- [x] 4.2 Update `Readr/Sources/codemap.md`, `ReadrTests/codemap.md`, the root
      status banners, and `project.yml`'s dependency note for the first plugins

## 5. Verification

- [x] 5.1 Run generate, generic simulator build, the iPhone 17 test suite, the
      bundle markdown check, SwiftLint, swift-format, and
      `openspec validate --all`
- [x] 5.2 Prove no source test contacts the live network and no concrete source
      type escapes `Readr/Sources/`, its tests, or
      `Readr/Core/DI/SourceRegistration.swift`
- [x] 5.3 Run the `reviewer` lane against the twelve invariants and the M4 spec
- [ ] 5.4 Archive `add-initial-source-plugins`
