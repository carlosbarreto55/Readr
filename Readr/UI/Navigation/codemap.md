# Codemap: `UI/Navigation/`

> **No implementation yet.**

Planned contents:

| File | Responsibility |
| --- | --- |
| `AppShell.swift` | Root `TabView`: Library, Browse, Downloads, Settings |
| `Route.swift` | Typed destination enum per tab |
| `NavigationPathStore.swift` | Per-tab `NavigationPath` ownership |

Series and Reader are pushed destinations, not tabs. Reader is presented as a
full-screen cover so it escapes the tab bar entirely.

Screens emit navigation as `Effect`s; this layer turns them into path mutations.
