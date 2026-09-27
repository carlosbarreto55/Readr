## 1. Zoom geometry and recognizers

- [x] 1.1 Create `Readr/UI/Reader/ZoomViewport.swift` with `ZoomGeometry` (clamp scale, clamp offset per layout, zoom about a focal point with vertical scroll correction, pan, settle); cover it in `ReadrTests/UI/ZoomGeometryTests.swift`
- [x] 1.2 In `Readr/UI/Reader/ZoomViewport.swift`, add the pinch and pan `UIGestureRecognizerRepresentable` wrappers (simultaneous with other recognizers, pan enabled only while zoomed) and the `ZoomViewport` view (vertical: shrunk viewport scaled from the top; paged: full viewport, both-axis pan, reports zoomed state)

## 2. Page renderer

- [x] 2.1 In `Readr/UI/Reader/PageRenderer.swift`, wrap both layouts in `ZoomViewport`, disable paged scrolling while zoomed, and add `initialZoom`; cover it in `ReadrTests/UI/PageRendererLayoutTests.swift` (2× keeps content size, 2× vertical still reaches later pages, 2× paged disables scrolling)

## 3. Text renderer

- [x] 3.1 In `Readr/UI/Reader/TextRenderer.swift`, add pinch-to-resize with a snapped preview scale and an `onTextScaleChanged` callback; wire it to `setTextScale` in `Readr/UI/Reader/ReaderContent.swift`; cover the pinch-to-scale mapping in `ReadrTests/UI/ZoomGeometryTests.swift`

## 4. Docs and verify

- [x] 4.1 Update `Readr/UI/Reader/codemap.md` for the zoom viewport and text pinch
- [x] 4.2 Run `/verify` and `openspec validate add-reader-zoom`
- [ ] 4.3 Check pinch, pan, and scroll on a device or the simulator in both layouts and on a text chapter before archiving
