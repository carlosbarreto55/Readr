## Why

On device, a manhwa chapter shows only its first page; scrolling lags, jumps back
to page 1, and leaves the rest of the screen black. Real AsuraScans pages are
strips up to 900×16000 px — about 7,000 points tall on a phone — and the page
renderer was built for page-sized images.

## What Changes

- Scrolling through a chapter never jumps back while pages load, however tall
  they are.
- Every page keeps its real height once known, so the chapter doesn't reflow
  under the reader.
- Pages are decoded at display width with a lookahead, and a page still loading
  says so rather than showing an empty dark area.
- Opening a chapter still restores the last page read.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `unified-reader-screen`: page images keep the reading position while they
  load.

## Impact

- **UI:** `Readr/UI/Reader/PageRenderer.swift`; a small change to
  `ReaderModel.positionChanged`.

## Non-goals

- Pinch-to-zoom, or changing the paged layout's behavior beyond position
  tracking.
