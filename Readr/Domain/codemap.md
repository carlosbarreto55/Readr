# Codemap: `Domain/`

> **No implementation yet.**

The framework-free core. Nothing here imports SwiftUI, SwiftData, `URLSession`,
or SwiftSoup — that is invariant 1, and it is what lets domain tests run without
a simulator.

Planned contents — repository protocols at this level, models in `Model/`:

| File | Responsibility |
| --- | --- |
| `SeriesRepository.swift` | Library membership, catalog browsing, series details |
| `ChapterRepository.swift` | Chapter lists, chapter content, read progress |
| `DownloadRepository.swift` | Download queue state and stored payload access |
| `SettingsRepository.swift` | Reader and app preferences |
| `SourceRepository.swift` | Source discovery and metadata |

Implementations live in `Data/Repository/`. Presentation depends on these
protocols only.
