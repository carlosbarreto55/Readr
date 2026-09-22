# Codemap: `UI/`

> **No screens yet.** The app currently shows a placeholder root view.

SwiftUI presentation. Read `AGENTS.md` in this directory before adding anything.

| Directory | Responsibility |
| --- | --- |
| `Navigation/` | Tab shell and typed navigation paths |
| `Library/` | Saved series |
| `Browse/` | Source catalogs: popular, latest, search |
| `Series/` | Series detail and chapter list |
| `Reader/` | The unified reader |
| `Downloads/` | Queue and stored chapters |
| `Settings/` | Preferences |
| `Components/` | Views shared by 2+ screens |
| `Theme/` | Colors, spacing, typography |

Every screen is four files — `<Name>Screen`, `<Name>Content`, `<Name>Model`,
`<Name>State`. The interface is designed for iOS rather than ported from the
Android original; `architecture.md` §9 records which divergences are
architectural.
