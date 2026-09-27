## Why

Manga and manhwa pages often carry small lettering in speech bubbles and fine
art that is hard to read at screen width, and the Reader has no way to look
closer. Novels can only change text size from the settings panel, which breaks
the reading flow.

## What Changes

- Page chapters (manga and manhwa) can be pinched to zoom between 1× and 3×, in
  both the vertical and the paged layout.
- In the vertical layout the reader keeps scrolling through the chapter while
  zoomed, and can pan sideways across the magnified strip.
- In the paged layout a zoomed page pans in every direction instead of turning.
  Pinching back to 1× restores page turning, and the next page opens at 1×.
- Zoom resets to 1× when the chapter or the page layout changes.
- Zooming never moves the reader away from the page they are reading and never
  changes which page counts as their reading position.
- Text chapters (novels) can be pinched to change text size. The size steps and
  limits are the same as the settings slider, the change reflows the text
  in place, and it persists like a slider change.
- A single tap still toggles the reader controls immediately. There is no
  double-tap zoom.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `unified-reader-screen`: adds pinch zoom for page chapters in both layouts and
  pinch-to-resize for text chapters. The leading-edge gesture requirement now
  also covers panning a zoomed page.

## Impact

- **UI:** `Readr/UI/Reader/PageRenderer.swift` gains a private zoom viewport
  that wraps the existing scroll view. The page layout, row heights, tiling,
  prefetching, and position observation are unchanged. `TextRenderer.swift`
  gains a pinch that reports a new text scale through the existing
  `setTextScale` action.
- **Domain / Data:** none. `ReaderPreferences.clampedScale` is reused as is.
- **Tests:** unit tests for the zoom geometry (scale and pan clamping, the pinch
  focal point) and for pinch-to-text-scale mapping; hosted layout tests showing
  that zoom leaves content size unchanged, still reaches later pages, and turns
  off paging while zoomed.
- **Docs:** `Readr/UI/Reader/codemap.md`.

## Non-goals

- Double-tap to zoom, or a zoom control in the reader chrome.
- Decoding pages above display resolution for sharper zoom.
- Remembering zoom across chapters or launches.
- Magnifying text chapters without reflowing them.
