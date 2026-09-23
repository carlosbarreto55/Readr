# Codemap: `UI/`

> **Every tab and destination is implemented.**

SwiftUI presentation. Read `AGENTS.md` in this directory before adding anything.

| Directory | Responsibility |
| --- | --- |
| `Navigation/` | Tab shell and typed navigation paths |
| `Library/` | Offline saved-series grid, filters, sorting, and membership removal |
| `Browse/` | Source selection and paged popular, latest, and search catalogs |
| `Series/` | Series detail, chapter list, and read state |
| `Reader/` | The unified reader |
| `Downloads/` | Queue, progress, and stored chapters |
| `Settings/` | Preferences |
| `Components/` | Shared series grid, card, cover, download-state indicator, and failure banner |
| `Theme/` | Colors, reader colors, spacing, typography |

Every screen is four files — `<Name>Screen`, `<Name>Content`, `<Name>Model`,
`<Name>State`. The interface is designed for iOS rather than ported from the
Android original; `architecture.md` §9 records which divergences are
architectural.
