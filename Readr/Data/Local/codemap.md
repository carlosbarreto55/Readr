# Codemap: `Data/Local/`

> **`Database/`, `Filesystem/`, and `Prefs/` implemented.** `Search/` is still
> empty — Spotlight indexing has not been built.

Local persistence, split by concern — see `architecture.md` §6.

| Directory | Stores |
| --- | --- |
| `Database/` | Structured metadata: library membership, chapter progress, download queue |
| `Filesystem/` | Downloaded chapter payloads |
| `Prefs/` | User preferences and reader settings |
| `Search/` | Core Spotlight index entries |

The split is deliberate: large payloads do not belong in a database, and
preferences do not belong in a schema that needs migrating.
