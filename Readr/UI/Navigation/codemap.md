# Codemap: `UI/Navigation/`

| File | Responsibility |
| --- | --- |
| `Routes.swift` | `AppTab`, one route enum per tab, and `ReaderRoute`. |
| `NavigationState.swift` | Selected tab, one path per tab, and a library revision bumped when a refresh outside Library changed stored state. |
| `RootTabView.swift` | Root `TabView`: real Library/Browse roots, series destinations on every tab, Downloads/Settings placeholders, one `NavigationStack` per tab, and the throttled library refresh on app activation. |
| `PlaceholderDestination.swift` | Stands in for the Downloads and Settings features that have not been built yet. |

Each tab has its own route type rather than sharing one app-wide enum; a shared
type would let any destination push any other. Route cases carry `(sourceID, url)`
rather than a whole `Series`, so a route stays cheap to compare and cannot go
stale against refreshed metadata.

Series and Reader are destinations, not tabs. `ReaderRoute` exists and is tested,
but nothing presents it yet — the Reader is presented as a full-screen cover, so
it escapes the tab bar entirely, when it is built.

Library, Browse, and Series emit navigation as `Effect`s and their screens turn
those into typed path mutations or presentations.

On `scenePhase == .active`, at most once per 15 minutes (`RefreshThrottle`), the
shell runs the library refresh — the foreground guarantee `architecture.md` §8
relies on.
