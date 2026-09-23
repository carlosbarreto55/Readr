# Codemap: `UI/`

> **Library and Browse implemented.** Downloads and Settings remain explicit tab
> placeholders; Series and Reader remain later navigation destinations.

SwiftUI presentation. Read `AGENTS.md` in this directory before adding anything.

| Directory | Responsibility |
| --- | --- |
| `Navigation/` | Tab shell and typed navigation paths |
| `Library/` | Offline saved-series grid, filters, sorting, and membership removal |
| `Browse/` | Source selection and paged popular, latest, and search catalogs |
| `Series/` | Series detail and chapter list |
| `Reader/` | The unified reader |
| `Downloads/` | Queue and stored chapters |
| `Settings/` | Preferences |
| `Components/` | Shared adaptive series grid, card, and NukeUI cover rendering |
| `Theme/` | Colors, spacing, typography |

Every screen is four files — `<Name>Screen`, `<Name>Content`, `<Name>Model`,
`<Name>State`. The interface is designed for iOS rather than ported from the
Android original; `architecture.md` §9 records which divergences are
architectural.
