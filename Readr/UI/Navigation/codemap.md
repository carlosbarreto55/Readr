# Codemap: `UI/Navigation/`

| File | Responsibility |
| --- | --- |
| `Routes.swift` | `AppTab`, one route enum per tab, and `ReaderRoute`. |
| `NavigationState.swift` | Selected tab and one path per tab. |
| `RootTabView.swift` | Root `TabView`: Library, Browse, Downloads, Settings, each wrapping its own `NavigationStack`. |
| `PlaceholderDestination.swift` | Stands in for a feature that has not been built yet, naming it. |

Each tab has its own route type rather than sharing one app-wide enum; a shared
type would let any destination push any other. Route cases carry `(sourceID, url)`
rather than a whole `Series`, so a route stays cheap to compare and cannot go
stale against refreshed metadata.

Series and Reader are destinations, not tabs. `ReaderRoute` exists and is tested,
but nothing presents it yet — the Reader is presented as a full-screen cover, so
it escapes the tab bar entirely, when it is built.

Planned: screens emit navigation as `Effect`s and this layer turns them into path
mutations. No screen emits one yet.
