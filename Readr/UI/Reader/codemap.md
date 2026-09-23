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
| `TextRenderer.swift` | Private renderer: text blocks → `AttributedString` per block in a lazy stack; position is the first visible block |
| `PageRenderer.swift` | Private renderer: vertical or paged image run via NukeUI, three-page prefetch, per-page retry |

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
