# Codemap: `UI/Reader/`

> **No implementation yet.**

One Reader screen for both content types. It branches once on `ChapterContent` to
pick a renderer and shares everything else.

Files: `ReaderScreen`, `ReaderContent`, `ReaderModel`, `ReaderState`, plus
private renderers:

| Renderer | Handles |
| --- | --- |
| `TextRenderer` | `.text(html:)` → `AttributedString` in a native text view |
| `PageRenderer` | `.pages(imageURLs:)` → vertical or paged image run via Nuke |

The text renderer is native rather than a web view so Dynamic Type, selection,
and reader themes work — see `architecture.md` §9. The domain still carries HTML;
only the rendering is native.

Reader chrome: tap to toggle, `.statusBarHidden`,
`.persistentSystemOverlays(.hidden)`. Horizontal paging must not begin at the
leading screen edge, which belongs to the system back gesture.

Specs: `unified-reader-screen`, `download-offline-reader`.
