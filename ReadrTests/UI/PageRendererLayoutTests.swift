import SwiftUI
import Testing
import UIKit

@testable import Readr

/// The page renderer hosted for real, in an on-screen window — the only way to
/// see what a lazy stack actually lays out.
///
/// Guards the bug where every page row carried the same inner `.id`, so the
/// stack treated all pages as one view: only the first ever appeared, and any
/// scroll sprang back to it.
@Suite("Page renderer layout", .serialized)
@MainActor
struct PageRendererLayoutTests {

    private final class Positions {
        var reported: [Int] = []
    }

    private func scrollView(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView { return scroll }
        for subview in view.subviews {
            if let scroll = scrollView(in: subview) { return scroll }
        }
        return nil
    }

    @Test("Scrolling down reaches later pages instead of springing back to the first")
    func scrollingReachesLaterPages() async throws {
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let positions = Positions()
        // Unreachable URLs: every page stays a one-screen placeholder, so the test
        // needs no network and still exercises layout.
        let urls = (0..<12).map { URL(string: "https://unreachable.invalid/\($0).jpg")! }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(
            rootView: PageRenderer(
                urls: urls, preferences: ReaderPreferences(), contentType: .manhwa,
                initialIndex: 0,
                onPositionChanged: { positions.reported.append($0) }, onReachedEnd: {},
                onTap: {}))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        try await waitUntil { self.scrollView(in: window) != nil }
        let scroll = try #require(scrollView(in: window))
        let screen = scroll.bounds.height
        #expect(scroll.contentSize.height > screen * 10)

        scroll.setContentOffset(CGPoint(x: 0, y: screen * 5.5), animated: false)
        try await waitUntil { (positions.reported.last ?? 0) >= 4 }

        #expect(scroll.contentOffset.y > screen * 5)
    }

    @Test("Paged manga uses right-to-left scroll layout")
    func mangaPagesAreRightToLeft() async throws {
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let urls = (0..<5).map { URL(string: "https://unreachable.invalid/\($0).jpg")! }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(
            rootView: PageRenderer(
                urls: urls, preferences: ReaderPreferences(), contentType: .manga,
                initialIndex: 0, onPositionChanged: { _ in }, onReachedEnd: {}, onTap: {}))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        try await waitUntil { self.scrollView(in: window)?.contentSize.width ?? 0 > 0 }
        let scroll = try #require(scrollView(in: window))
        #expect(scroll.effectiveUserInterfaceLayoutDirection == .rightToLeft)
        #expect(scroll.contentSize.width >= scroll.bounds.width * 5)
    }

    // MARK: Zoom

    /// Hosts a renderer at `zoom` and returns its scroll view once laid out.
    private func hostedScroll(
        pages: Int, contentType: ContentType, preferences: ReaderPreferences = ReaderPreferences(),
        zoom: CGFloat, onPositionChanged: @escaping (Int) -> Void = { _ in }
    ) async throws -> (UIWindow, UIScrollView) {
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let urls = (0..<pages).map { URL(string: "https://unreachable.invalid/\($0).jpg")! }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(
            rootView: PageRenderer(
                urls: urls, preferences: preferences, contentType: contentType,
                initialIndex: 0, onPositionChanged: onPositionChanged, onReachedEnd: {},
                onTap: {}, initialZoom: zoom))
        window.makeKeyAndVisible()
        try await waitUntil {
            let size = self.scrollView(in: window)?.contentSize ?? .zero
            return size.width > 0 && size.height > 0
        }
        return (window, try #require(scrollView(in: window)))
    }

    @Test("Zooming leaves the vertical chapter's content size unchanged")
    func zoomKeepsContentSize() async throws {
        let (plain, plainScroll) = try await hostedScroll(
            pages: 12, contentType: .manhwa, zoom: 1)
        let plainSize = plainScroll.contentSize
        plain.isHidden = true

        let (zoomed, zoomedScroll) = try await hostedScroll(
            pages: 12, contentType: .manhwa, zoom: 2)
        defer { zoomed.isHidden = true }

        #expect(zoomedScroll.contentSize == plainSize)
        // The viewport shrinks instead, so the scaled result fills the screen.
        #expect(abs(zoomedScroll.bounds.height - plainScroll.bounds.height / 2) < 1)
    }

    @Test("A zoomed vertical chapter still scrolls on to later pages")
    func zoomedScrollingReachesLaterPages() async throws {
        let positions = Positions()
        let (window, scroll) = try await hostedScroll(
            pages: 12, contentType: .manhwa, zoom: 2,
            onPositionChanged: { positions.reported.append($0) })
        defer { window.isHidden = true }
        // Unloaded rows are one reader height tall; the viewport is half that.
        let row = scroll.bounds.height * 2

        scroll.setContentOffset(CGPoint(x: 0, y: row * 5.5), animated: false)
        try await waitUntil { (positions.reported.last ?? 0) >= 5 }

        #expect(scroll.contentOffset.y > row * 5)
    }

    @Test("A zoomed page pans instead of paging, and pages again at 1×")
    func zoomedPageDisablesPaging() async throws {
        let paged = ReaderPreferences(pageLayout: .paged)
        let (zoomed, zoomedScroll) = try await hostedScroll(
            pages: 5, contentType: .manhwa, preferences: paged, zoom: 2)
        #expect(!zoomedScroll.isScrollEnabled)
        zoomed.isHidden = true

        let (plain, plainScroll) = try await hostedScroll(
            pages: 5, contentType: .manhwa, preferences: paged, zoom: 1)
        defer { plain.isHidden = true }
        #expect(plainScroll.isScrollEnabled)
    }
}
