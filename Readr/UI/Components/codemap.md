# Codemap: `UI/Components/`

> **No implementation yet.**

Views used by two or more screens. A view used by exactly one screen stays in
that screen's directory until a second caller appears.

Planned contents:

| File | Used by |
| --- | --- |
| `SeriesCard.swift` | Library, Browse |
| `SeriesCatalogGrid.swift` | Library, Browse |
| `ChapterListSheet.swift` | Series, Reader |
| `CoverImage.swift` | Anywhere a cover is shown (wraps Nuke) |

`CoverImage` is the only component permitted to import Nuke outside the reader's
page renderer.
