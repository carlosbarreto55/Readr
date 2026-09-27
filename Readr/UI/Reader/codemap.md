# Codemap: `UI/Reader/`

> **Implemented in M7.**

One Reader screen for both content types. It branches once on the loaded
document to pick a renderer and shares everything else.

| File | Responsibility |
| --- | --- |
| `ReaderScreen.swift` | Reads `AppContainer`, owns `ReaderModel`, flushes progress and dismisses on close |
| `ReaderContent.swift` | The shared surface: renderer selection, chrome, the back edge, chapter-list and reader-settings panels, failure states; owns previews |
| `ReaderModel.swift` | Loads chapters and content, enforces the one-forced-fetch mismatch rule, parses text off the main actor, records progress coarsely and in order, applies preferences |
| `ReaderState.swift` | Render state, document, actions, and the close effect |
| `TextRenderer.swift` | Private renderer: text blocks → `AttributedString` per block in a lazy stack; position is the first visible block. A pinch steps the text-size preference, previewing each snapped step as a reflow and reporting it on release |
| `PageRenderer.swift` | Private renderer: vertical or paged image run via NukeUI, with right-to-left paging for manga and left-to-right for every other type; each image type's layout comes from `ReaderPreferences.pageLayout(for:)`. Observes (never binds) the scroll position and restores it once; gives every row an explicit height (aspect ratio once known, else one screen) and never puts an `.id` inside a lazy row; draws tall strips as ≤2048-px tiles; decodes at display width with a three-page prefetch; per-page retry |
| `ZoomViewport.swift` | Pinch zoom (1×–3×) for the page renderer. Scales and offsets the viewport around the scroll view and never the rows, so content size, row heights, and position observation stay the same at any zoom. Vertical: the viewport is `height / scale` tall and keeps scrolling the chapter, and a pan moves it sideways. Paged: a zoomed page pans on both axes and paging is disabled until 1×. `ZoomGeometry` holds the math; native pinch and pan recognizers run alongside the scroll view |

The text renderer is native rather than a web view so Dynamic Type, selection,
and reader themes work — see `architecture.md` §9. The domain still carries HTML;
`Core/Util/ChapterTextParser` reduces it to blocks.

Reader chrome: tap to toggle, `.statusBarHidden`,
`.persistentSystemOverlays(.hidden)`. A strip along the leading edge absorbs
touches and turns a rightward drag into back, so paging never begins there.

The bottom bar's download control queues the current chapter and then shows its
state. Stored chapters are served from disk by the chapter repository, so the
Reader renders them identically offline.

Progress is a 0–1 fraction (block or page index over the count), written when it
moves 5%, at the end, on chapter change, and on close. Series outside the library
read without stored progress, and the top bar says so.

Specs: `unified-reader-screen`, `download-offline-reader`.
