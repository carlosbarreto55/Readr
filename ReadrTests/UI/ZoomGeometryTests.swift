import CoreGraphics
import Testing
import UIKit

@testable import Readr

@Suite("Zoom geometry")
struct ZoomGeometryTests {
    private let size = CGSize(width: 400, height: 800)

    @Test("Scale stays between 1× and 3×")
    func scaleIsClamped() {
        #expect(ZoomGeometry.clampedScale(0.4) == 1)
        #expect(ZoomGeometry.clampedScale(2) == 2)
        #expect(ZoomGeometry.clampedScale(9) == 3)
        #expect(ZoomGeometry.clampedScale(.nan) == 1)
    }

    @Test("A zoomed viewport can never be pulled inside the screen")
    func offsetIsClamped() {
        let paged = ZoomGeometry.clampedOffset(
            CGPoint(x: -900, y: 50), scale: 2, size: size, layout: .paged)
        #expect(paged == CGPoint(x: -400, y: 0))

        let pagedFar = ZoomGeometry.clampedOffset(
            CGPoint(x: 30, y: -5000), scale: 2, size: size, layout: .paged)
        #expect(pagedFar == CGPoint(x: 0, y: -800))
    }

    @Test("The vertical layout never offsets vertically; its scroll view does")
    func verticalOffsetIsHorizontalOnly() {
        let offset = ZoomGeometry.clampedOffset(
            CGPoint(x: -100, y: -300), scale: 2, size: size, layout: .vertical)
        #expect(offset == CGPoint(x: -100, y: 0))
    }

    @Test("At 1× nothing can be offset")
    func unzoomedHasNoOffset() {
        let offset = ZoomGeometry.clampedOffset(
            CGPoint(x: -100, y: -100), scale: 1, size: size, layout: .paged)
        #expect(offset == .zero)
    }

    @Test("Zooming a page keeps the point under the fingers in place")
    func pagedZoomKeepsFocalPoint() {
        let focal = CGPoint(x: 100, y: 200)
        let result = ZoomGeometry.zoom(
            ZoomState(), to: 2, about: focal, size: size, layout: .paged)
        #expect(result.state.scale == 2)
        // Content point (100, 200) is drawn at offset + point × scale.
        #expect(result.state.offset == CGPoint(x: -100, y: -200))
        #expect(result.scrollCorrection == 0)
    }

    @Test("Zooming a vertical chapter scrolls to keep the point under the fingers")
    func verticalZoomCorrectsScroll() {
        let focal = CGPoint(x: 200, y: 400)
        let result = ZoomGeometry.zoom(
            ZoomState(), to: 2, about: focal, size: size, layout: .vertical)
        #expect(result.state.offset == CGPoint(x: -200, y: 0))
        // Before, y 400 on screen is content 400 below the scroll offset; after,
        // it is 200 below it, so the content scrolls 200 further.
        #expect(result.scrollCorrection == 200)
    }

    @Test("Zooming out past 1× stops at 1× with no offset or scroll")
    func zoomingOutStopsAtOne() {
        let result = ZoomGeometry.zoom(
            ZoomState(), to: 0.5, about: CGPoint(x: 10, y: 10), size: size, layout: .vertical)
        #expect(result.state == ZoomState())
        #expect(result.scrollCorrection == 0)
    }

    @Test("Zooming in past 3× stops at 3×")
    func zoomingInStopsAtThree() {
        let result = ZoomGeometry.zoom(
            ZoomState(scale: 2.5), to: 6, about: .zero, size: size, layout: .paged)
        #expect(result.state.scale == 3)
    }

    @Test("A zoomed viewport follows the finger within its edges")
    func panIsClamped() {
        let zoomed = ZoomState(scale: 2, offset: CGPoint(x: -100, y: -100))
        let paged = ZoomGeometry.pan(
            zoomed, by: CGPoint(x: -1000, y: 40), size: size, layout: .paged)
        #expect(paged.offset == CGPoint(x: -400, y: -60))

        let vertical = ZoomGeometry.pan(
            ZoomState(scale: 2, offset: CGPoint(x: -100, y: 0)), by: CGPoint(x: 30, y: 90),
            size: size, layout: .vertical)
        #expect(vertical.offset == CGPoint(x: -70, y: 0))
    }

    @Test("An unzoomed viewport does not pan")
    func unzoomedDoesNotPan() {
        let state = ZoomGeometry.pan(
            ZoomState(), by: CGPoint(x: -50, y: -50), size: size, layout: .paged)
        #expect(state == ZoomState())
    }

    @Test("A pinch released just above 1× settles at 1×")
    func nearlyUnzoomedSettles() {
        let nearly = ZoomState(scale: 1.03, offset: CGPoint(x: -5, y: -5))
        #expect(ZoomGeometry.settled(nearly) == ZoomState())
        let zoomed = ZoomState(scale: 1.5, offset: CGPoint(x: -5, y: -5))
        #expect(ZoomGeometry.settled(zoomed) == zoomed)
    }

    @Test("A scroll correction stays within the content")
    func scrollCorrectionIsClamped() {
        let insets = UIEdgeInsets.zero
        #expect(
            ZoomGeometry.scrolledOffset(
                100, by: 200, contentHeight: 5000, viewportHeight: 400, insets: insets) == 300)
        #expect(
            ZoomGeometry.scrolledOffset(
                100, by: -500, contentHeight: 5000, viewportHeight: 400, insets: insets) == 0)
        #expect(
            ZoomGeometry.scrolledOffset(
                4500, by: 500, contentHeight: 5000, viewportHeight: 400, insets: insets) == 4600)
    }

    @Test("Pinching text steps the text scale within the setting's range")
    func textPinchStepsTextScale() {
        let range = ReaderPreferences.textScaleRange
        #expect(isClose(TextRenderer.pinchedScale(from: 1, factor: 1.26), 1.3))
        #expect(isClose(TextRenderer.pinchedScale(from: 1.5, factor: 0.8), 1.2))
        #expect(isClose(TextRenderer.pinchedScale(from: 1, factor: 5), range.upperBound))
        #expect(isClose(TextRenderer.pinchedScale(from: 1, factor: 0.1), range.lowerBound))
    }

    /// Text scales are multiples of 0.1, which binary floating point rounds.
    private func isClose(_ value: Double, _ expected: Double) -> Bool {
        abs(value - expected) < 1e-9
    }
}
