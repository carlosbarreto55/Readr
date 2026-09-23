## Context

`PageRenderer` bound `.scrollPosition(id:)` two-way over a `LazyVStack` of
`LazyImage`s whose placeholders were a fixed 2:3 box. SwiftUI keeps the bound id
pinned when content sizes change; each loaded strip changed size by thousands of
points, so the scroll view re-anchored to the bound page — page 0 at first. The
renderer also decoded pages at full resolution and allocated an
`ImagePrefetcher` on every parent re-render.

## Goals / Non-Goals

**Goals:** stable scrolling through strips of any height; restore still works.

**Non-Goals:** zoom; changing paged mode's presentation.

## Decisions

### Observe the position; restore it once

The renderer no longer binds a scroll position. It reports the first visible page
from `onScrollTargetVisibilityChange`, and restores the starting page once with
`ScrollViewReader.scrollTo` on appear. Nothing re-anchors while the reader
scrolls.

### Remember each page's real aspect ratio

Each page reports its image size when it loads; the renderer keeps the ratios and
sizes every cell with them, loaded or not. An unknown page is one screen tall, so
placeholders neither fake a short box nor let a dozen pages start at once.

### Decode at display width

Each page's request resizes to the container width in pixels, without upscaling,
and the prefetcher uses the same requests, so prefetched images are cache hits.
The prefetcher is created once per renderer.

### Quiet position updates

`ReaderModel.positionChanged` ignores an index that doesn't change progress.

## Risks / Trade-offs

- **Visibility callbacks are coarse** → position is a page index anyway.

## Migration Plan

None. Rollback is `git revert`.

## Open Questions

None.
