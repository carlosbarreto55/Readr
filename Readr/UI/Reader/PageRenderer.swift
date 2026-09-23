import Nuke
import NukeUI
import SwiftUI

/// Renders `.pages(imageURLs:)` in reading order: one continuous vertical run, or
/// horizontal pages.
///
/// Nuke is confined here and to `CoverImage` (`architecture.md` §8). Its bounded
/// memory cache and a three-page lookahead are what keep a long webtoon chapter
/// from stuttering or being terminated for memory.
struct PageRenderer: View {
    let urls: [URL]
    let preferences: ReaderPreferences
    let onPositionChanged: (Int) -> Void
    let onReachedEnd: () -> Void
    let onTap: () -> Void

    @State private var position: Int?
    @State private var prefetcher = ImagePrefetcher()

    private static let lookahead = 3

    init(
        urls: [URL],
        preferences: ReaderPreferences,
        initialIndex: Int,
        onPositionChanged: @escaping (Int) -> Void,
        onReachedEnd: @escaping () -> Void,
        onTap: @escaping () -> Void
    ) {
        self.urls = urls
        self.preferences = preferences
        self.onPositionChanged = onPositionChanged
        self.onReachedEnd = onReachedEnd
        self.onTap = onTap
        _position = State(initialValue: initialIndex)
    }

    var body: some View {
        Group {
            switch preferences.pageLayout {
            case .vertical: vertical
            case .paged: paged
            }
        }
        .scrollPosition(id: $position)
        .onChange(of: position, initial: true) { _, index in
            guard let index else { return }
            onPositionChanged(index)
            prefetch(after: index)
            if preferences.pageLayout == .paged, index == urls.count - 1 {
                onReachedEnd()
            }
        }
        .onDisappear { prefetcher.stopPrefetching() }
        .contentShape(.rect)
        .onTapGesture(perform: onTap)
        .background(ReaderColors.background(preferences.theme))
    }

    private var vertical: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(urls.indices, id: \.self) { index in
                    PageImage(url: urls[index], number: index + 1, theme: preferences.theme)
                        .id(index)
                }
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
                    PageImage(url: urls[index], number: index + 1, theme: preferences.theme)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: position)
    }

    private func prefetch(after index: Int) {
        let next = urls.dropFirst(index + 1).prefix(Self.lookahead)
        prefetcher.startPrefetching(with: Array(next))
    }
}

/// One page: the image at its natural aspect ratio, a stable placeholder while
/// it loads, and a retry when it fails.
private struct PageImage: View {
    let url: URL
    let number: Int
    let theme: ReaderTheme

    @State private var attempt = 0

    var body: some View {
        LazyImage(url: url) { state in
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
        .id(attempt)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Page \(number)")
    }

    private var placeholder: some View {
        ZStack {
            ReaderColors.background(theme)
            ProgressView()
        }
        .aspectRatio(2 / 3, contentMode: .fit)
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
        .frame(maxWidth: .infinity)
        .aspectRatio(2 / 3, contentMode: .fit)
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
