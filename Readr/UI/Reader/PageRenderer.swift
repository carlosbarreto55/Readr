import Nuke
import NukeUI
import SwiftUI

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
    let initialIndex: Int
    let onPositionChanged: (Int) -> Void
    let onReachedEnd: () -> Void
    let onTap: () -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var containerWidth: CGFloat = 0
    @State private var aspectRatios: [Int: CGFloat] = [:]
    @State private var reportedIndex: Int?
    @State private var hasRestored = false
    @State private var prefetcher: ImagePrefetcher?

    private static let lookahead = 3

    var body: some View {
        ScrollViewReader { proxy in
            Group {
                switch preferences.pageLayout {
                case .vertical: vertical
                case .paged: paged
                }
            }
            .onScrollTargetVisibilityChange(idType: Int.self, threshold: 0.2) { visible in
                visibleChanged(visible)
            }
            .onAppear {
                guard !hasRestored else { return }
                hasRestored = true
                if initialIndex > 0 {
                    proxy.scrollTo(initialIndex, anchor: .top)
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: { width in
            containerWidth = width
        }
        .onAppear {
            if prefetcher == nil {
                prefetcher = ImagePrefetcher()
            }
        }
        .onDisappear { prefetcher?.stopPrefetching() }
        .contentShape(.rect)
        .onTapGesture(perform: onTap)
        .background(ReaderColors.background(preferences.theme))
    }

    private var vertical: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(urls.indices, id: \.self) { index in
                    page(index)
                        .frame(maxWidth: .infinity)
                        .modifier(PageHeight(aspectRatio: aspectRatios[index]))
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
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
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

    /// Resized to the pixels actually drawn, never upscaled. `nil` until the
    /// width is known, so nothing is decoded at the wrong size first.
    private func request(for url: URL) -> ImageRequest? {
        guard containerWidth > 0 else { return nil }
        return ImageRequest(
            url: url,
            processors: [
                ImageProcessors.Resize(
                    width: containerWidth * displayScale, unit: .pixels, upscale: false)
            ])
    }

    private func visibleChanged(_ visible: [Int]) {
        guard let first = Self.firstVisible(visible), first != reportedIndex else { return }
        reportedIndex = first
        onPositionChanged(first)
        prefetch(after: first)
        if preferences.pageLayout == .paged, visible.contains(urls.count - 1) {
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

/// A page's height: its image's real aspect ratio once known, else one screen.
private struct PageHeight: ViewModifier {
    let aspectRatio: CGFloat?

    func body(content: Content) -> some View {
        if let aspectRatio {
            content.aspectRatio(aspectRatio, contentMode: .fit)
        } else {
            content.containerRelativeFrame(.vertical)
        }
    }
}

/// One page: the image, a labelled placeholder while it loads, and a retry when
/// it fails. Reports the loaded image's size so its height survives re-creation.
private struct PageImage: View {
    let request: ImageRequest?
    let number: Int
    let theme: ReaderTheme
    let onLoaded: (CGSize) -> Void

    @State private var attempt = 0

    var body: some View {
        LazyImage(request: request) { state in
            if let image = state.image {
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
            if case .success(let response) = result {
                onLoaded(response.image.size)
            }
        }
        .id(attempt)
        .accessibilityLabel("Page \(number)")
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
            Button("Try Again") { attempt += 1 }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Page renderer placeholders") {
    PageRenderer(
        urls: (1...3).map { URL(string: "https://example.invalid/page-\($0).jpg")! },
        preferences: ReaderPreferences(),
        initialIndex: 0,
        onPositionChanged: { _ in },
        onReachedEnd: {},
        onTap: {}
    )
}
