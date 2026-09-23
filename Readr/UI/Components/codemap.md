# Codemap: `UI/Components/`

> **Catalog components implemented.** Library and Browse share one adaptive grid,
> one card, and one Nuke-backed cover view. Chapter/reader components remain M6–M7.

Views used by two or more screens. A view used by exactly one screen stays in
that screen's directory until a second caller appears.

Planned contents:

| File | Used by |
| --- | --- |
| `SeriesCard.swift` | Library and Browse card value, cover/title/source layout, tap, and membership context menu |
| `SeriesCatalogGrid.swift` | Adaptive Library/Browse grid with a scaled card minimum and stable scroll anchor |
| `ChapterListSheet.swift` | Series, Reader |
| `CoverImage.swift` | NukeUI cover loading plus stable missing/loading/failure placeholder |

`CoverImage` is the only component permitted to import NukeUI outside the
reader's page renderer.
