# Codemap: `Data/`

> **No implementation yet.**

Everything that talks to the outside world, plus the orchestration that decides
when to.

| Directory | Responsibility |
| --- | --- |
| `Repository/` | Implementations of the `Domain/` protocols. The only layer allowed to see both source plugins and local storage. |
| `Source/` | The `Source` protocol, `HTMLSource` base type, and `SourceRegistry`. |
| `Local/Database/` | SwiftData models, mappers, schema versions, migrations. |
| `Local/Filesystem/` | Downloaded chapter payload storage. |
| `Local/Prefs/` | `UserDefaults`-backed settings. |
| `Local/Search/` | Core Spotlight indexing. |
