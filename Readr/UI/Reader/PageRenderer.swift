import Nuke
import NukeUI
import SwiftUI
import UIKit

/// Renders `.pages(imageURLs:)` in reading order: one continuous vertical run, or
/// horizontal pages.
///
/// Nuke is confined here and to `CoverImage` (`architecture.md` §8). Its bounded
/// memory cache and a three-page lookahead are what keep a long webtoon chapter
/// from stuttering or being terminated for memory.
///
/// Webtoon pages are strips — a real one is 900×16000 px, several screens tall —
/// which shapes three choices here:
/// - The scroll position is **observed, never bound.** A bound position is
///   re-pinned by SwiftUI whenever content size changes, and every strip that
///   finishes loading changes size by thousands of points, so a bound reader is
///   yanked back to the page it was bound to. The starting page is restored once.
/// - Each page's **real aspect ratio is remembered** once its image loads, so a
///   page keeps its height when it is re-created and the chapter does not reflow
///   under the reader. An unknown page is one screen tall.
/// - Pages are **decoded at display width**, with the prefetcher asking for the
///   same requests so prefetched pages are cache hits.
struct PageRenderer: View {
    let urls: [URL]
    let preferences: ReaderPreferences
    let contentType: ContentType
    let initialIndex: Int
    let onPositionChanged: (Int) -> Void
    let onReachedEnd: () -> Void
    let onTap: () -> Void

    @Environment(\.displayScale) private var displayScale
    /// The reader's visible size. Every row's height is computed from it: a row
    /// must never depend on layout it cannot see, or it collapses to nothing.
    @State private var containerSize: CGSize = .zero
    @State private var aspectRatios: [Int: CGFloat] = [:]
    @State private var reportedIndex: Int?
    @State private var hasRestored = false
    @State private var prefetcher: ImagePrefetcher?

    private static let lookahead = 3

    private var layout: ReaderPageLayout {
        contentType == .manga ? preferences.mangaPageLayout : preferences.pageLayout
    }

    var body: some View {
        ScrollViewReader { proxy in
            Group {
                if containerSize == .zero {
                    Color.clear
                } else {
                    switch layout {
                    case .vertical: vertical
                    case .paged: paged
                    }
                }
            }
            // A tiny threshold: a strip several screens tall never shows more than
            // a small fraction of itself, and must still count as on screen.
            .onScrollTargetVisibilityChange(idType: Int.self, threshold: 0.001) { visible in
                visibleChanged(visible)
            }
            .onChange(of: containerSize == .zero) { _, isZero in
                // Restored once, when there is a layout to restore into.
                guard !isZero, !hasRestored else { return }
                hasRestored = true
                if initialIndex > 0 {
                    proxy.scrollTo(initialIndex, anchor: .top)
                }
            }
        }
        .onGeometryChange(for: CGSize.self) {
            $0.size
        } action: { size in
            containerSize = size
        }
        .onAppear {
            if prefetcher == nil {
                prefetcher = ImagePrefetcher()
            }
        }
        .onDisappear {
            prefetcher?.stopPrefetching()
        }
        .contentShape(.rect)
        .onTapGesture(perform: onTap)
        .background(ReaderColors.background(preferences.theme))
    }

    private var vertical: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(urls.indices, id: \.self) { index in
                    page(index)
                        .frame(width: containerSize.width, height: rowHeight(index))
                        .id(index)
                }
                // Reaching this is reaching the end of the chapter.
                Color.clear
                    .frame(height: 1)
                    .onAppear(perform: onReachedEnd)
            }
            .scrollTargetLayout()
        }
    }

    private var paged: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(urls.indices, id: \.self) { index in
                    page(index)
                        .frame(width: containerSize.width, height: containerSize.height)
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .environment(\.layoutDirection, contentType == .manga ? .rightToLeft : .leftToRight)
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: reportedIndex)
    }

    private func page(_ index: Int) -> some View {
        PageImage(
            request: request(for: urls[index]),
            number: index + 1,
            theme: preferences.theme,
            onLoaded: { size in
                guard size.width > 0, size.height > 0, aspectRatios[index] == nil else {
                    return
                }
                aspectRatios[index] = size.width / size.height
            }
        )
    }

    /// A page's height in the vertical run: its real aspect ratio once known,
    /// else one screen — explicit either way, so no row is ever zero tall.
    private func rowHeight(_ index: Int) -> CGFloat {
        guard let ratio = aspectRatios[index], ratio > 0 else {
            return max(containerSize.height, 1)
        }
        return max(containerSize.width / ratio, 1)
    }

    /// Resized to the pixels actually drawn, never upscaled. `nil` until the
    /// width is known, so nothing is decoded at the wrong size first.
    private func request(for url: URL) -> ImageRequest? {
        guard containerSize.width > 0 else { return nil }
        return ImageRequest(
            url: url,
            processors: [
                // Fit to the drawn width. The width-only initializer also clamps
                // height, which would shrink a tall strip to half its width.
                ImageProcessors.Resize(
                    size: CGSize(width: containerSize.width * displayScale, height: 100_000),
                    unit: .pixels, contentMode: .aspectFit, upscale: false)
            ])
    }

    private func visibleChanged(_ visible: [Int]) {
        guard let first = Self.firstVisible(visible), first != reportedIndex else { return }
        reportedIndex = first
        onPositionChanged(first)
        prefetch(after: first)
        if layout == .paged, visible.contains(urls.count - 1) {
            onReachedEnd()
        }
    }

    private func prefetch(after index: Int) {
        let upcoming = urls.dropFirst(index + 1).prefix(Self.lookahead)
        prefetcher?.startPrefetching(with: upcoming.compactMap(request(for:)))
    }

    /// The reading position among visible pages: the earliest one.
    static func firstVisible(_ visible: [Int]) -> Int? {
        visible.min()
    }
}

/// One page: the image, a labelled placeholder while it loads, and a retry when
/// it fails. Reports the loaded image's size so its height survives re-creation.
///
/// A loaded page is drawn as horizontal tiles, never as one bitmap. Webtoon
/// strips reach 16,000 px — the GPU's texture limit — and a layer that tall is
/// laid out at full height but drawn as nothing.
private struct PageImage: View {
    let request: ImageRequest?
    let number: Int
    let theme: ReaderTheme
    let onLoaded: (CGSize) -> Void

    @State private var attempt = 0
    @State private var tiles: [UIImage] = []

    var body: some View {
        LazyImage(request: attemptRequest) { state in
            if !tiles.isEmpty {
                VStack(spacing: 0) {
                    ForEach(tiles.indices, id: \.self) { index in
                        Image(uiImage: tiles[index])
                            .resizable()
                            .scaledToFit()
                    }
                }
            } else if let image = state.image {
                image
                    .resizable()
                    .scaledToFit()
            } else if state.error != nil {
                failed
            } else {
                placeholder
            }
        }
        .onCompletion { result in
            guard case .success(let response) = result else { return }
            onLoaded(response.image.size)
            tiles = PageTiles.split(response.image)
        }
        .accessibilityLabel("Page \(number)")
    }

    /// Retrying changes the request rather than the view's identity. An `.id`
    /// inside a lazy row — the same value in every row — makes the stack treat
    /// every page as one view, so only the first ever appears.
    private var attemptRequest: ImageRequest? {
        guard var request, attempt > 0 else { return request }
        request.options.insert(.reloadIgnoringCachedData)
        // LazyImage reloads when its request changes; alternate so each retry is
        // a change.
        request.priority = attempt.isMultiple(of: 2) ? .high : .veryHigh
        return request
    }

    private var placeholder: some View {
        VStack(spacing: Spacing.small) {
            ProgressView()
                .tint(ReaderColors.text(theme))
            Text("Loading page \(number)…")
                .font(Typography.caption)
                .foregroundStyle(ReaderColors.secondaryText(theme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderColors.background(theme))
    }

    private var failed: some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(ReaderColors.secondaryText(theme))
            Text("Page \(number) didn’t load.")
                .font(Typography.body)
                .foregroundStyle(ReaderColors.text(theme))
            Button("Try Again") {
                tiles = []
                attempt += 1
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Cuts a page image into horizontal strips short enough to draw.
enum PageTiles {
    /// Comfortably under every supported GPU's texture limit.
    static let maxTileHeight = 2048

    /// The strips, top to bottom, as rects in pixels. One rect for an image short
    /// enough to draw whole; none for an empty image.
    static func rects(width: Int, height: Int, maxTileHeight: Int = maxTileHeight) -> [CGRect] {
        guard width > 0, height > 0, maxTileHeight > 0 else { return [] }
        return stride(from: 0, to: height, by: maxTileHeight).map { top in
            CGRect(x: 0, y: top, width: width, height: min(maxTileHeight, height - top))
        }
    }

    /// The image as drawable strips. Cropping shares the decoded pixels; no
    /// strip copies the whole page.
    static func split(_ image: UIImage) -> [UIImage] {
        guard let cgImage = image.cgImage else { return [image] }
        let rects = rects(width: cgImage.width, height: cgImage.height)
        guard rects.count > 1 else { return [image] }
        return rects.compactMap { rect in
            cgImage.cropping(to: rect).map {
                UIImage(cgImage: $0, scale: image.scale, orientation: .up)
            }
        }
    }
}

#Preview("Page renderer placeholders") {
    PageRenderer(
        urls: (1...3).map { URL(string: "https://example.invalid/page-\($0).jpg")! },
        preferences: ReaderPreferences(),
        contentType: .manhwa,
        initialIndex: 0,
        onPositionChanged: { _ in },
        onReachedEnd: {},
        onTap: {}
    )
}
