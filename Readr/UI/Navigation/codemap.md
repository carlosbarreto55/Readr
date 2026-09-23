# Codemap: `UI/Navigation/`

| File | Responsibility |
| --- | --- |
| `Routes.swift` | `AppTab`, one route enum per tab, and `ReaderRoute`. |
| `NavigationState.swift` | Selected tab and one path per tab. |
| `RootTabView.swift` | Root `TabView`: real Library/Browse roots and typed destinations; Downloads/Settings placeholders; one `NavigationStack` per tab. |
| `PlaceholderDestination.swift` | Stands in for the Downloads and Settings features that have not been built yet. |

Each tab has its own route type rather than sharing one app-wide enum; a shared
type would let any destination push any other. Route cases carry `(sourceID, url)`
rather than a whole `Series`, so a route stays cheap to compare and cannot go
stale against refreshed metadata.

Series and Reader are destinations, not tabs. `ReaderRoute` exists and is tested,
but nothing presents it yet — the Reader is presented as a full-screen cover, so
it escapes the tab bar entirely, when it is built.

Library and Browse emit navigation as `Effect`s and their screens turn those into
typed path mutations. The temporary series-route body is replaced by M6's detail
screen without changing the route value.
