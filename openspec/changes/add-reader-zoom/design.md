## Context

`PageRenderer` draws page chapters as a SwiftUI `ScrollView`: a vertical
`LazyVStack` or a horizontal paging `LazyHStack`, with right-to-left paging for
manga. Two recent fixes (`fix-manhwa-page-rendering`, archived 2026-09-23) set
some rules for that view. The scroll position is observed, never bound. Every
row gets an explicit height from the measured container. No row carries an inner
`.id`. Tall strips are drawn as tiles of at most 2048 px. The reader lost its
place whenever the content size changed or row identity collapsed.

`TextRenderer` draws text chapters as native `Text` blocks sized by Dynamic Type
× `preferences.textScale`. Its position is bound by block id with a top anchor.

`ReaderContent` recreates the renderer when the chapter changes
(`documentGeneration`) and when the page layout changes. It lays a
leading-edge strip over the renderer that takes touches for back.

The deployment target is iOS 26, so `UIGestureRecognizerRepresentable` (iOS 18)
is available.

## Goals / Non-Goals

**Goals:**

- Pinch zoom (1×–3×) for page chapters in both layouts, for manga and manhwa.
- Leave the scroll content untouched: row heights, tiles, content size,
  laziness, and position observation are the same at every zoom.
- Pinch-to-resize text in text chapters, using the existing text-size
  preference.

**Non-Goals:**

- Double-tap zoom, sharper decoding for zoom, and zoom that persists. See the
  proposal.

## Decisions

### 1. Magnify the viewport, never the content

A new private `ZoomViewport` wraps the renderer's `ScrollView` and applies
`scaleEffect` plus a clamped `offset` to it. The scroll view's content never
learns about the zoom.

- *Alternative: scale the rows* (row height × s, tiles × s). Rejected. The
  content size would change on every pinch frame, and that is how the reader
  lost its place in the two earlier fixes.
- *Alternative: rewrite the vertical reader as a zooming `UIScrollView`/
  `UICollectionView`.* Rejected as too much work for the risk it takes on. It
  would discard the renderer that was only just stabilised.

This is the approach Mihon's `WebtoonRecyclerView` uses: the list scrolls
unscaled, and the view that holds it is scaled and translated.

### 2. Vertical layout: shrink the viewport, scale from the top

At scale `s`, the inner scroll view is given a frame of `W × H/s`. It is scaled
by `s` from its top-leading corner, so on screen it fills exactly `sW × H`. Only
a horizontal offset `x ∈ [-(s-1)W, 0]` is needed. Vertical movement stays the
scroll view's own scrolling, so the reader scrolls through the whole chapter at
any zoom. The scroll view's visible bounds are exactly what is on screen, so
page visibility and progress are still accurate.

Row heights come from `containerSize`, which is measured outside the viewport.
They stay the same when the viewport shrinks.

To keep the point under the fingers fixed during a pinch, the vertical part of
the correction is a scroll: `Δy = f.y/s₀ − f.y/s₁` content points. The pinch
finds the `UIScrollView` under its location (hit test, then walk up the
superviews) and adjusts `contentOffset` by that amount. If no scroll view is
found, the zoom simply stays anchored at the top, which is still correct, only
less comfortable. It adjusts the scroll offset directly, as a user's scroll
would. Nothing binds the position, so nothing can re-pin it.

### 3. Paged layout: full viewport, pan both axes, paging off while zoomed

The paging scroll view keeps its full frame and is scaled from the top-leading
corner, with an offset clamped to `x ∈ [-(s-1)W, 0]` and `y ∈ [-(s-1)H, 0]`.
While `s > 1`, the inner view gets `.scrollDisabled(true)`, so a drag pans
instead of turning the page. At 1× paging comes back. The reader can't turn the
page while zoomed, so every newly shown page opens at 1×. The offset is applied
outside the right-to-left environment, so it is in screen coordinates for manga
too.

### 4. Native recognizers through `UIGestureRecognizerRepresentable`

The pinch and the pan are `UIPinchGestureRecognizer` and `UIPanGestureRecognizer`
wrapped in `UIGestureRecognizerRepresentable`. They are attached to the
viewport's unscaled container, so locations and translations are in screen
points. Each one's delegate allows it to run alongside other recognizers, which
lets a zoomed vertical drag scroll through the inner scroll view and pan
sideways through the recognizer at the same time. The pan is enabled only while
zoomed, so an unzoomed reader behaves exactly as today.

- *Alternative: SwiftUI `MagnifyGesture`/`DragGesture` as
  `simultaneousGesture` on a `ScrollView`.* Rejected. Running them alongside
  the scroll view's own gestures has been unreliable, and there is no delegate to
  control that.

There is no double-tap recognizer, so the existing single-tap chrome toggle is
never delayed.

### 5. The geometry is pure and tested on its own

A `ZoomGeometry` enum holds the math as static functions: clamp the scale, clamp
the offset for a layout, zoom about a focal point (new offset plus vertical
scroll correction), pan, and settle (a scale below 1.05 settles to exactly 1×).
The view only applies the results. This follows `PageTiles.rects` and
`PageRenderer.firstVisible`.

### 6. Text: pinch steps the text-size preference

`TextRenderer` attaches the same pinch recognizer. During a pinch it shows a
preview scale `clampedScale(start × pinch)`, which snaps to 0.1 steps. That
means at most about a dozen reflows across the whole range, not one per frame.
On release it reports the scale through a new `onTextScaleChanged` callback,
which `ReaderContent` maps to the existing `setTextScale` action. The model
already clamps and persists that action. The block-id `scrollPosition` with a
top anchor keeps the passage the reader was on in place as the text reflows.

### 7. Reset comes from existing identity

The renderer's `.id` already changes with the chapter and the layout, so the
zoom state lives in the recreated view and resets to 1× with nothing added.

### 8. Tests start the renderer already zoomed

`PageRenderer` gains `initialZoom: CGFloat = 1`, passed to the viewport. The
hosted layout tests use it to open a renderer at 2× without driving a pinch.

## Risks / Trade-offs

- [SwiftUI changes how a scaled `UIScrollView` is hit-tested] → hosted tests
  scroll a 2× renderer and check that it still reaches later pages. Pinching is
  checked on a device before the change is archived.
- [Pinching resizes the vertical viewport on every frame] → a frame change
  is layout only. Content size and offsets don't move. If it stutters, the
  frame can be committed when the pinch ends, with a live `scaleEffect` preview
  during the pinch.
- [Finding the scroll view depends on the SwiftUI `ScrollView` being backed by
  `UIScrollView`] → the existing layout tests already rely on that. If it
  isn't, the zoom falls back to top-anchored. It never fails outright.
- [Zoomed pages are the display-width bitmap scaled up] → accepted and listed
  in the non-goals. Typical sources are already at or under display width.
- [Two-finger pinch at 1× in the paged layout may also nudge the paging scroll]
  → paging snaps back, and the scale clamps. Accepted.

## Migration Plan

UI only, with no stored data. To roll back, revert the change.

## Open Questions

None blocking. How it feels on a device (Pinching speed, whether `1.05` is the
right settle threshold) is tuned during the device check.
