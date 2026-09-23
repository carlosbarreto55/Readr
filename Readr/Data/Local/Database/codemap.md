# Codemap: `Data/Local/Database/`

SwiftData. Read `AGENTS.md` in this directory before changing anything here.

| File | Responsibility |
| --- | --- |
| `SeriesEntity.swift` | Current `@Model` for a saved series (declared in `SchemaV2`, aliased at top level). Presence means library membership. |
| `ChapterEntity.swift` | Current `@Model` for a chapter, the reader's progress through it, its source position, and whether the source still lists it. |
| `SchemaV1.swift` | The first `VersionedSchema`, frozen: exact copies of the models v1 shipped with, so the plan can recognize and migrate a v1 store. |
| `SchemaV2.swift` | Adds `ChapterEntity.sourceIndex` and `isListedUpstream`. |
| `ReadrMigrationPlan.swift` | `CurrentSchema`, and the `SchemaMigrationPlan` the container is opened through: v1 → v2 lightweight. |
| `EntityKey.swift` | Derives both persisted keys from `(sourceID, url)`. |
| `SeriesMapper.swift` | `SeriesEntity` → `Series` / `LibraryItem`, plus `Series` → entity. Free functions, not methods. |
| `ChapterMapper.swift` | `ChapterEntity` ↔ `Chapter` / `LibraryChapter`. Free functions, not methods. |

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

Versioning: each released schema's models live inside its `VersionedSchema` and
are never edited again. The top-level `SeriesEntity` / `ChapterEntity` names are
typealiases to `CurrentSchema`'s, so repositories and mappers never name a
version. SwiftData's entity name is the unqualified class name, which is why the
frozen copies keep the names the store on disk already uses.

`StoreSurvivalTests` writes a v1 store through the frozen models, reopens it
through the plan, and asserts identity, metadata, read state, and the new
attributes' defaults survived.
