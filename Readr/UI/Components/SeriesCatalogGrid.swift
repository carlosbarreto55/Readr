import SwiftUI

/// The adaptive catalog grid shared by Library and Browse.
///
/// Scaling the minimum card width with Dynamic Type is intentional: at larger
/// accessibility sizes fewer columns fit, giving titles room to wrap instead of
/// pinning the grid to an unreadable fixed count.
struct SeriesCatalogGrid: View {
    let items: [SeriesCardItem]
    let onOpen: (SeriesID) -> Void
    let onToggleLibrary: (Series) -> Void
    let onLoadMore: () -> Void

    @ScaledMetric(relativeTo: .body) private var minimumCardWidth: CGFloat = 128
    @State private var firstVisibleID: SeriesID?

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: minimumCardWidth),
                        spacing: Spacing.large,
                        alignment: .top)
                ],
                alignment: .leading,
                spacing: Spacing.xLarge
            ) {
                ForEach(items) { item in
                    SeriesCard(
                        item: item,
                        onOpen: { onOpen(item.id) },
                        onMembershipAction: { onToggleLibrary(item.series) }
                    )
                    .onAppear {
                        if item.id == items.last?.id {
                            onLoadMore()
                        }
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.vertical, Spacing.large)
        }
        .scrollPosition(id: $firstVisibleID, anchor: .top)
    }
}

#Preview("Adaptive catalog") {
    let entries = (1...8).map { index in
        SeriesCardItem(
            series: Series(
                sourceID: 42,
                url: URL(string: "https://example.test/series/\(index)")!,
                title: index.isMultiple(of: 2)
                    ? "A Long Sample Title That Wraps Across Several Lines"
                    : "Series \(index)",
                contentType: index.isMultiple(of: 2) ? .manhwa : .novel
            ),
            sourceName: index.isMultiple(of: 2) ? "AsuraScans" : "FreeWebNovel",
            isSaved: index.isMultiple(of: 3)
        )
    }

    SeriesCatalogGrid(
        items: entries,
        onOpen: { _ in },
        onToggleLibrary: { _ in },
        onLoadMore: {}
    )
}
