# Codemap: `UI/Navigation/`

| File | Responsibility |
| --- | --- |
| `Routes.swift` | `AppTab`, one route enum per tab, and `ReaderRoute`. |
| `NavigationState.swift` | Selected tab, one path per tab, the presented `ReaderRoute`, a library revision bumped when a refresh or reading changed stored state, and `open(_:)` for Spotlight results plus the shell's notice. |
| `AppAppearanceModel.swift` | The app theme as observable state and its environment key. Built by `ReadrApp`, which applies its color scheme to the whole window; Settings writes through it. |
| `RootTabView.swift` | Root `TabView`: the four real tab roots, series destinations on every tab, the Reader's full-screen cover, one `NavigationStack` per tab, and the throttled library refresh on app activation. |

Each tab has its own route type rather than sharing one app-wide enum; a shared
type would let any destination push any other. Route cases carry `(sourceID, url)`
rather than a whole `Series`, so a route stays cheap to compare and cannot go
stale against refreshed metadata.

Series and Reader are destinations, not tabs. The Reader is presented as a
full-screen cover from `NavigationState.presentedReader`, so it escapes the tab
bar entirely; clearing it bumps `libraryRevision` so Library and Series re-read
progress.

Library, Browse, and Series emit navigation as `Effect`s and their screens turn
those into typed path mutations or presentations.

On `scenePhase == .active`, at most once per 15 minutes (`RefreshThrottle`), the
shell runs the library refresh — the foreground guarantee `architecture.md` §8
relies on.

Spotlight results arrive as `CSSearchableItemActionType` activities.
`RootTabView` resolves them through the system-search repository and
`NavigationState.open(_:)` acts: a saved series opens on Library over anything
presented; a removed one shows a notice and navigates nowhere.
