# Codemap: `Data/Local/Filesystem/`

> **No implementation yet.**

Planned contents:

| File | Responsibility |
| --- | --- |
| `DownloadStore.swift` | Protocol: write, read, delete, and size chapter payloads |
| `DownloadStoreImpl.swift` | Implementation over Application Support |

Layout:

```
Application Support/Readr/Downloads/<sourceID>/<seriesKey>/<chapterKey>/
```

`Downloads/` has `isExcludedFromBackup` set. Application Support rather than
Caches, because the system evicts Caches under disk pressure and offline reading
is the whole point. See `architecture.md` §6.3.
