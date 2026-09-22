## 1. Schema v1

All files in this section live in `Readr/Data/Local/Database/`. The identity,
relationship, and delete-rule decisions in `design.md` are approved; do not
deviate from them without a new approval.

- [x] 1.1 `SeriesEntity.swift` — `@Model` with a derived `@Attribute(.unique) key`,
      `sourceID`, `url`, metadata, `dateAdded`, `lastReadAt`, and a `chapters`
      relationship carrying `deleteRule: .cascade`
- [x] 1.2 `ChapterEntity.swift` — `@Model` with the same derived unique `key`, plus
      `isRead`, `readingPosition`, and `lastReadAt`
- [x] 1.3 `SchemaV1.swift` — the `VersionedSchema`, and `ReadrMigrationPlan.swift`
      — the `SchemaMigrationPlan` with `SchemaV1` as its only version and no
      stages yet. The container is opened through the plan from the first release
- [x] 1.4 `EntityKey.swift` — the one place `"\(sourceID)|\(url)"` is derived, and
      the one place a download path key is derived as hex of `stableHash64`. Test
      in `ReadrTests/Data/EntityKeyTests.swift` asserting hardcoded expected
      values for both, since a path key that drifts strands downloaded files
- [x] 1.5 `SeriesMapper.swift`, `ChapterMapper.swift` — free functions, not methods
      on the entities. Test in `ReadrTests/Data/MapperTests.swift` that a domain
      value survives a round trip with every field and its identity intact

## 2. Preferences

- [x] 2.1 `Readr/Domain/SettingsStore.swift` — the protocol. Plain Swift; no
      `UserDefaults` in any signature
- [x] 2.2 `Readr/Data/Local/Prefs/UserDefaultsSettingsStore.swift` — the only
      place `UserDefaults` is named. Every key declares a default
- [x] 2.3 `ReadrTests/Data/SettingsStoreTests.swift` — an unset preference returns
      its declared default, an uninterpretable stored value returns the default
      rather than failing, and a written value reads back

## 3. Library repository

- [x] 3.1 `Readr/Domain/LibraryRepository.swift` — the protocol. Domain structs in
      and out; no `@Model` type and no SwiftData import
- [x] 3.2 `Readr/Data/Repository/SwiftDataLibraryRepository.swift` — add, remove,
      and fetch saved series; owns entity/domain translation. **No observation
      API**: nothing consumes one until the Library screen exists in M5, and a
      stream with no reader is the same speculation as a protocol with no caller
- [x] 3.3 `ReadrTests/Data/LibraryRepositoryTests.swift` — against an in-memory
      `ModelContainer`: a saved series reads back, saving the same series twice
      does not duplicate it, removal takes its chapters with it, and a series
      whose metadata changed is still the same series
- [x] 3.4 Record the follow-up that removal must also delete downloaded payloads
      once download storage exists in M8. `library-browse-catalog` requires it and
      there is nothing to delete yet
- [x] 3.5 Record the follow-up that stored reader state — `isRead`,
      `readingPosition`, `lastReadAt` — is persisted and round-trips, but no
      repository method reaches it yet. M6 adds the accessors and the
      repository-level test that sets read state, refreshes the chapter list, and
      asserts it survived. Today that guarantee is only covered at the mapper

## 4. Composition

- [x] 4.1 `Readr/Core/DI/AppContainer.swift` — build the `ModelContainer` from
      `ReadrMigrationPlan` and hold the repositories. A container that fails to
      open surfaces the failure through `StoreUnavailableView`; it never deletes
      the store to recover. The environment entry became `AppContainer?` with no
      default, closing the M1 review's finding that an empty default container
      would hide a missed injection behind an empty-looking library
- [x] 4.2 Confirm the tabs still show placeholders. This change ships no UI

## 5. Migration harness

- [x] 5.1 `ReadrTests/Data/StoreSurvivalTests.swift` — write at `SchemaV1`, reopen
      through `ReadrMigrationPlan`, assert the data is intact and still reachable
      by `(sourceID, url)`. There is no migration to test yet; this is the harness
      every future migration test extends, so write it to be extended

## 6. Documentation

- [x] 6.1 Update the `codemap.md` of `Readr/Data/Local/Database/`,
      `Readr/Data/Local/Prefs/`, `Readr/Data/Repository/`, `Readr/Domain/`,
      `Readr/Core/DI/`, and `ReadrTests/`
- [x] 6.2 Update the status banners in `codemap.md`, `AGENTS.md`,
      `architecture.md`, and `README.md`

## 7. Verification

- [x] 7.1 Run the verification sequence — generate, build, test, bundle check,
      lint, format, `openspec validate --all`
- [x] 7.2 Prove invariant 12 mechanically: no `@Model` type name and no
      `import SwiftData` appears under `Readr/Domain/` or in any repository
      protocol
- [x] 7.3 Prove `live()` opens a real store: launched in the simulator, confirmed
      `Application Support/default.store` is created with the `SeriesEntity` and
      `ChapterEntity` tables, and confirmed it survives terminate-and-relaunch.
      `StoreSurvivalTests` covers the write/close/reopen path on disk
- [x] 7.4 Run the `reviewer` lane over the diff against the twelve invariants.
      Clean on all twelve. Eight findings, all addressed:
      `chapters(for:)` no longer promises an order SwiftData does not guarantee;
      `removeAll()` is bounded to `SettingNamespace` instead of the whole
      `UserDefaults` domain, with `SettingKey`/`RawSettingKey` enforcing the
      prefix; `storeChapters` rejects a chapter whose `(sourceID, seriesURL)`
      names a different series, which closed a path that silently reparented a
      stored chapter and its read state; `AppContainer.modelContainer` is private
      so no view has a route to a `ModelContext`; the database `AGENTS.md`
      boundary wording matches `architecture.md` §6.1; the stale open question is
      resolved in `design.md`; and the missing tests — `savedSeries` ordering,
      preference survival across store instances, `removeAll` scope, foreign
      chapter rejection — now exist
- [x] 7.5 `openspec archive add-persistence-layer` so `preferences-store` becomes
      normative
