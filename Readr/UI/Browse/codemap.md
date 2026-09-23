# Codemap: `UI/Browse/`

> **Implemented in M5.** Presentation sees `CatalogRepository` and
> `LibraryRepository`, never the registry or either concrete plugin.

Source catalogs — popular, latest, and full-text search — with paging.

| File | Responsibility |
| --- | --- |
| `BrowseScreen.swift` | Reads `AppContainer`, owns one source-list/catalog model, refreshes membership on tab selection, and handles effects |
| `BrowseContent.swift` | Stateless source list and explicit catalog loading/empty/error/grid rendering; owns previews |
| `BrowseModel.swift` | Source discovery, request switching, `CatalogPager` delegation, stale-response rejection, and optimistic membership |
| `BrowseState.swift` | Source/catalog state, request identity, actions, and typed navigation effects |

Specs: `library-browse-catalog`, `source-listing-pagination`,
`series-catalog-ui`.
