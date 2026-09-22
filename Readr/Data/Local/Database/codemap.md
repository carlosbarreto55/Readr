# Codemap: `Data/Local/Database/`

> **No implementation yet.**

SwiftData persistence. See `AGENTS.md` in this directory before changing
anything here.

Planned contents:

| File | Responsibility |
| --- | --- |
| `SeriesModel.swift` | `@Model` for a library series |
| `ChapterModel.swift` | `@Model` for a chapter and its read state |
| `DownloadQueueModel.swift` | `@Model` for a queue entry |
| `SchemaV1.swift` | The initial `VersionedSchema` |
| `MigrationPlan.swift` | `SchemaMigrationPlan` listing every stage in order |
| `Mappers/` | `@Model` ↔ domain `struct` translation |

`@Model` types never leave this directory. That is invariant 12, and
`architecture.md` §6.1 explains why SwiftData's requirements make it necessary.
