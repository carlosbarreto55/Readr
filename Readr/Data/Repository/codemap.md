# Codemap: `Data/Repository/`

> **No implementation yet.**

Repository implementations. These coordinate `SourceRegistry`, SwiftData,
the filesystem, and Spotlight — and they are the only layer permitted to.

Planned contents:

| File | Responsibility |
| --- | --- |
| `SeriesRepositoryImpl.swift` | Library membership, catalog paging, detail refresh, blank-title repair |
| `ChapterRepositoryImpl.swift` | Chapter list refresh with state preservation, content resolution (downloaded before remote) |
| `DownloadRepositoryImpl.swift` | Sequential queue, progress reporting, stored payload lookup |
| `SettingsRepositoryImpl.swift` | Preferences, mapped to and from `AppSettings` |
| `SourceRepositoryImpl.swift` | Source listing and cached source metadata |

Error policy lives here. Sources throw; repositories decide what that means for
the user.
