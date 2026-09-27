import SwiftUI
import UIKit

/// How a page layout magnifies.
enum ZoomLayout: Sendable {
    /// The chapter keeps scrolling vertically at any zoom; a zoom adds only a
    /// sideways pan.
    case vertical
    /// A zoomed page pans in both directions, and paging waits for 1×.
    case paged
}

/// A renderer's magnification: the scale, and where the scaled viewport's
/// top-leading corner sits on screen.
struct ZoomState: Equatable, Sendable {
    var scale: CGFloat = 1
    var offset: CGPoint = .zero

    var isZoomed: Bool { scale > 1 }
}

/// The zoom math, kept out of the view so it can be tested on its own.
///
/// The viewport is scaled from its top-leading corner, so a content point `c`
/// is drawn at `offset + c × scale`. Offsets are never positive, so the
/// viewport's edges can never be pulled inside the screen.
enum ZoomGeometry {
    static let scaleRange: ClosedRange<CGFloat> = 1...3
    /// A pinch released below this settles to exactly 1×, so a nearly
    /// unzoomed page never keeps paging disabled.
    static let settleThreshold: CGFloat = 1.05

    /// The result of a pinch step.
    struct Zoom: Equatable {
        var state: ZoomState
        /// Vertical layout only: content points to scroll by so the point under
        /// the fingers stays there.
        var scrollCorrection: CGFloat
    }

    static func clampedScale(_ scale: CGFloat) -> CGFloat {
        guard scale.isFinite else { return 1 }
        return min(max(scale, scaleRange.lowerBound), scaleRange.upperBound)
    }

    /// Keeps the scaled viewport covering the screen. The vertical layout
    /// never offsets vertically: its scroll view does that job.
    static func clampedOffset(
        _ offset: CGPoint, scale: CGFloat, size: CGSize, layout: ZoomLayout
    ) -> CGPoint {
        let offsetX = min(max(offset.x, -(scale - 1) * size.width), 0)
        switch layout {
        case .vertical:
            return CGPoint(x: offsetX, y: 0)
        case .paged:
            return CGPoint(x: offsetX, y: min(max(offset.y, -(scale - 1) * size.height), 0))
        }
    }

    /// Zooms to `newScale` about `focal`, a point in screen space.
    ///
    /// The vertical viewport is `height / scale` tall and scaled from its top,
    /// so the content under `focal.y` is `scrollOffset + focal.y / scale`;
    /// keeping it under the fingers is a scroll, not an offset.
    static func zoom(
        _ state: ZoomState, to newScale: CGFloat, about focal: CGPoint, size: CGSize,
        layout: ZoomLayout
    ) -> Zoom {
        let current = state.scale
        let target = clampedScale(newScale)
        let offsetX = focal.x - (focal.x - state.offset.x) * target / current
        let offsetY: CGFloat
        let correction: CGFloat
        switch layout {
        case .vertical:
            offsetY = 0
            correction = focal.y / current - focal.y / target
        case .paged:
            offsetY = focal.y - (focal.y - state.offset.y) * target / current
            correction = 0
        }
        let offset = clampedOffset(
            CGPoint(x: offsetX, y: offsetY), scale: target, size: size, layout: layout)
        return Zoom(state: ZoomState(scale: target, offset: offset), scrollCorrection: correction)
    }

    /// Moves a zoomed viewport with the finger. An unzoomed one never moves.
    static func pan(
        _ state: ZoomState, by translation: CGPoint, size: CGSize, layout: ZoomLayout
    ) -> ZoomState {
        guard state.isZoomed else { return state }
        let moved = CGPoint(x: state.offset.x + translation.x, y: state.offset.y + translation.y)
        return ZoomState(
            scale: state.scale,
            offset: clampedOffset(moved, scale: state.scale, size: size, layout: layout))
    }

    /// The state a released pinch settles into.
    static func settled(_ state: ZoomState) -> ZoomState {
        state.scale < settleThreshold ? ZoomState() : state
    }

    /// A scroll offset moved by `delta` and kept within the content.
    static func scrolledOffset(
        _ current: CGFloat, by delta: CGFloat, contentHeight: CGFloat, viewportHeight: CGFloat,
        insets: UIEdgeInsets
    ) -> CGFloat {
        let minY = -insets.top
        let maxY = max(contentHeight + insets.bottom - viewportHeight, minY)
        return min(max(current + delta, minY), maxY)
    }
}

/// Magnifies a renderer's scroll view without the scroll view knowing.
///
/// The content — rows, tiles, content size, scroll position — is identical at
/// every zoom; only the viewport is scaled and moved. Resizing the content
/// under a lazy stack is what once threw readers back to page 1.
///
/// - Vertical: the scroll view is `height / scale` tall and scaled from its
///   top, so it exactly fills the screen and keeps scrolling the chapter. Its
///   visible bounds are still exactly what is on screen, so page visibility is
///   unaffected.
/// - Paged: the scroll view keeps its full size; `content` is told it is
///   zoomed so it can stop paging while the page pans.
struct ZoomViewport<Content: View>: View {
    let layout: ZoomLayout
    let size: CGSize
    let content: (_ isZoomed: Bool) -> Content

    @State private var zoom: ZoomState
    @State private var scrollView = ScrollViewReference()

    init(
        layout: ZoomLayout, size: CGSize, initialScale: CGFloat = 1,
        @ViewBuilder content: @escaping (_ isZoomed: Bool) -> Content
    ) {
        self.layout = layout
        self.size = size
        self.content = content
        _zoom = State(initialValue: ZoomState(scale: ZoomGeometry.clampedScale(initialScale)))
    }

    var body: some View {
        content(zoom.isZoomed)
            .frame(width: size.width, height: viewportHeight(at: zoom.scale))
            .scaleEffect(zoom.scale, anchor: .topLeading)
            .offset(x: zoom.offset.x, y: zoom.offset.y)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipped()
            .contentShape(.rect)
            .gesture(
                PinchRecognizer(
                    onBegan: { scrollView.view = $0 },
                    onChanged: pinched,
                    onEnded: { zoom = ZoomGeometry.settled(zoom) }
                )
            )
            .gesture(PanRecognizer(isEnabled: zoom.isZoomed, onChanged: panned))
    }

    private func viewportHeight(at scale: CGFloat) -> CGFloat {
        layout == .vertical ? size.height / scale : size.height
    }

    private func pinched(by factor: CGFloat, at focal: CGPoint) {
        let result = ZoomGeometry.zoom(
            zoom, to: zoom.scale * factor, about: focal, size: size, layout: layout)
        if result.scrollCorrection != 0, let scroll = scrollView.view {
            scroll.contentOffset.y = ZoomGeometry.scrolledOffset(
                scroll.contentOffset.y, by: result.scrollCorrection,
                contentHeight: scroll.contentSize.height,
                viewportHeight: viewportHeight(at: result.state.scale),
                insets: scroll.adjustedContentInset)
        }
        zoom = result.state
    }

    private func panned(by translation: CGPoint) {
        zoom = ZoomGeometry.pan(zoom, by: translation, size: size, layout: layout)
    }
}

/// The scroll view under the current pinch. A reference, so recording it does
/// not re-render.
@MainActor
private final class ScrollViewReference {
    weak var view: UIScrollView?
}

/// Lets a zoom gesture run alongside the scroll view's own pan, so a zoomed
/// vertical chapter scrolls and pans sideways in one drag.
@MainActor
final class SimultaneousRecognition: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

/// A native pinch. Reports each step as a factor on the previous one, at the
/// pinch's location in the attached view's space.
struct PinchRecognizer: UIGestureRecognizerRepresentable {
    /// Receives the scroll view under the pinch, if there is one.
    var onBegan: (UIScrollView?) -> Void = { _ in }
    var onChanged: (_ factor: CGFloat, _ location: CGPoint) -> Void
    var onEnded: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> SimultaneousRecognition {
        SimultaneousRecognition()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPinchGestureRecognizer {
        let recognizer = UIPinchGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(
        _ recognizer: UIPinchGestureRecognizer, context: Context
    ) {
        switch recognizer.state {
        case .began, .changed:
            if recognizer.state == .began {
                onBegan(Self.scrollView(under: recognizer))
            }
            let factor = recognizer.scale
            recognizer.scale = 1
            onChanged(factor, context.converter.localLocation)
        case .ended, .cancelled, .failed:
            onEnded()
        default:
            break
        }
    }

    /// The nearest scroll view at the pinch's location.
    private static func scrollView(under recognizer: UIGestureRecognizer) -> UIScrollView? {
        guard let view = recognizer.view else { return nil }
        var hit = view.hitTest(recognizer.location(in: view), with: nil)
        while let current = hit {
            if let scroll = current as? UIScrollView { return scroll }
            hit = current.superview
        }
        return nil
    }
}

/// A native one-finger pan, reported as the movement since the last step in
/// screen points. Idle unless `isEnabled`, so it never competes with an
/// unzoomed reader's scrolling.
struct PanRecognizer: UIGestureRecognizerRepresentable {
    var isEnabled: Bool
    var onChanged: (_ translation: CGPoint) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> SimultaneousRecognition {
        SimultaneousRecognition()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.maximumNumberOfTouches = 1
        recognizer.delegate = context.coordinator
        recognizer.isEnabled = isEnabled
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        guard recognizer.state == .changed else { return }
        let translation = recognizer.translation(in: nil)
        recognizer.setTranslation(.zero, in: nil)
        onChanged(translation)
    }
}
