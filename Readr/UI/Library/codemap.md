# Codemap: `UI/Library/`

> **Implemented in M5.** The screen reads only repository contracts and remains
> usable from saved metadata with no source network available.

Saved series with persisted content/source filters and title/date-added/last-read
sorting. Removal is optimistic and rolls back visibly on persistence failure.

| File | Responsibility |
| --- | --- |
| `LibraryScreen.swift` | Reads `AppContainer`, owns `LibraryModel`, reloads on Library-tab selection, and turns effects into typed routes |
| `LibraryContent.swift` | Stateless loading/empty/error/filter-empty/grid rendering and filter/sort menus; owns previews |
| `LibraryModel.swift` | Loads `LibraryItem`s, resolves local source names, filters/sorts, persists selections, and removes membership |
| `LibraryState.swift` | Render state, filter/sort values, actions, and navigation effect |

Specs: `library-browse-catalog`, `library-filtering`,
`library-search-via-spotlight`, `library-blank-title-repair`,
`series-catalog-ui`.
