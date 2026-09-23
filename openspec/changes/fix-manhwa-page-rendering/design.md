## Context

**Root cause, found by reproducing in a hosted simulator window:** every page
row carried `.id(attempt)` for its retry button — `0` in every row. An inner
`.id` with the same value in every row makes `LazyVStack` treat all rows as one
view, so only the first page is ever laid out as content; later rows are never
realized, never load, and any scroll springs back to page 1. Bisection showed
the containers and modifiers were fine; a nested `.id` alone reproduces it.

The items below were found along the way and are fixed too.


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

### No `.id` inside a lazy row

Retry reloads by changing the image request (cache-bypassing, alternating
priority), which `LazyImage` observes, instead of changing view identity. A
hosted layout test scrolls the real renderer and fails if later pages are never
reached.

### Explicit row heights; tiny visibility threshold

Rows get explicit heights from the measured reader size: the image's aspect
ratio once known, else one screen. Visibility uses a near-zero threshold, since
a strip several screens tall never shows more than a small fraction of itself.

### Tall pages drawn as tiles

A loaded page is cut into ≤2048-px strips (sharing the decoded pixels), so no
single layer approaches the GPU texture limit.


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

Each page's request fits the container width in pixels (aspect-fit into a very
tall box — the width-only initializer also clamps height), without upscaling,
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
