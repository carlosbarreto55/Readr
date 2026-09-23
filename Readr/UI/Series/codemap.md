# Codemap: `UI/Series/`

> **Implemented in M6.**

Series detail: cover, metadata, synopsis, library toggle, continue reading, and
the chapter list with read state.

| File | Responsibility |
| --- | --- |
| `SeriesScreen.swift` | Reads `AppContainer`, owns `SeriesModel`, and handles effects. The reader route is presented by M7. |
| `SeriesContent.swift` | Stateless loading/failed/loaded rendering, chapter rows with swipe and context-menu read actions, recoverable banners, pull-to-refresh; owns previews |
| `SeriesModel.swift` | Shows stored state first, then refreshes; optimistic membership with rollback; read-state writes; chapter order preference; reader-route effects |
| `SeriesState.swift` | Render state, chapter order, actions, and effects |

A saved series renders from the store before any network request. A refresh that
fails while content is shown becomes a dismissible banner rather than an error
screen. The chapter list direction is a presentation preference; reading order
itself comes from `ChapterReadingOrder`.

Specs: `source-detail-parsing`, `chapter-refresh-state-preservation`,
`library-blank-title-repair`.
