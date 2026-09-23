# Codemap: `UI/Components/`

> **Implemented.** Library and Browse share one adaptive grid, one card, and one
> Nuke-backed cover view; Series and Reader share the download-state indicator;
> Library and Series share the failure banner.

Views used by two or more screens. A view used by exactly one screen stays in
that screen's directory until a second caller appears.

| File | Used by |
| --- | --- |
| `SeriesCard.swift` | Library and Browse card value, cover/title/source layout, tap, and membership context menu |
| `SeriesCatalogGrid.swift` | Adaptive Library/Browse grid with a scaled card minimum and stable scroll anchor |
| `DownloadStateIndicator.swift` | Series chapter rows and the Reader's download control |
| `FailureBanner.swift` | Library removal failures and Series refresh/membership failures |
| `CoverImage.swift` | NukeUI cover loading plus stable missing/loading/failure placeholder |

`CoverImage` is the only component permitted to import NukeUI outside the
reader's page renderer.
