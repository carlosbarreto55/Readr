# Codemap: `Data/Local/Database/`

SwiftData. Read `AGENTS.md` in this directory before changing anything here.

| File | Responsibility |
| --- | --- |
| `SeriesEntity.swift` | `@Model` for a saved series. Presence means library membership. |
| `ChapterEntity.swift` | `@Model` for a chapter and the reader's progress through it. |
| `SchemaV1.swift` | The first `VersionedSchema`, and `ReadrMigrationPlan`, the `SchemaMigrationPlan` the container is opened through. |
| `EntityKey.swift` | Derives both persisted keys from `(sourceID, url)`. |
| `SeriesMapper.swift` | `SeriesEntity` → `Series` / `LibraryItem`, plus `Series` → entity. Free functions, not methods. |
| `ChapterMapper.swift` | `ChapterEntity` ↔ `Chapter`. Free functions, not methods. |

`@Model` classes are persistence types and never leave this directory
(invariant 12). Mappers are free functions rather than methods on the entities,
because a method would invite callers to reach for it from outside the repository.

`EntityKey` derives two different keys, both from `(sourceID, url)`:

- **identity** — `"<sourceID>|<url>"`, the `@Attribute(.unique)` column. Carries
  the URL in full, because a collision would merge two series into one. SwiftData
  has no composite unique constraint, so this is how invariant 9 is enforced by
  the store rather than by convention.
- **path** — 16 hex characters of `stableHash64`, a filesystem path component for
  `Downloads/<sourceID>/<seriesKey>/<chapterKey>/`. Hashed because it must be
  short and safe; not reversible, because the store is the index from a path back
  to a chapter.

Both are persisted format. The path key names directories that already hold
downloaded files, so changing its derivation strands them — `EntityKeyTests`
asserts hardcoded values for both.

Enums are stored as their raw values rather than as enums, so a case rename cannot
silently reinterpret existing rows.

`ReadrMigrationPlan` holds no stages: `SchemaV1` is the only version. It exists so
that the first real schema change is a stage rather than a rewrite.
`StoreSurvivalTests` is the harness that migration's test will extend.
