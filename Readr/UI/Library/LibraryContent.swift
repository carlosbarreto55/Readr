import SwiftUI

struct LibraryContent: View {
    let state: LibraryState
    let onAction: (LibraryAction) -> Void
    /// Pull-to-refresh. Async so the system spinner stays up until the library
    /// refresh has actually finished.
    var onRefresh: @MainActor () async -> Void = {}

    var body: some View {
        Group {
            switch state.phase {
            case .loading:
                ProgressView("Loading Library…")
            case .empty:
                ContentUnavailableView {
                    Label("Your Library Is Empty", systemImage: "books.vertical")
                } description: {
                    Text("Add a series from Browse and it will appear here, even when offline.")
                }
            case .error(let message):
                ContentUnavailableView {
                    Label("Couldn’t Load Library", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") { onAction(.retry) }
                        .buttonStyle(.borderedProminent)
                }
            case .filteredEmpty:
                ContentUnavailableView {
                    Label("No Matching Series", systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text("Your filters are hiding the series in your library.")
                } actions: {
                    Button("Clear Filters") { onAction(.clearFilters) }
                        .buttonStyle(.borderedProminent)
                }
            case .searchEmpty(let query):
                ContentUnavailableView.search(text: query)
            case .populated:
                SeriesCatalogGrid(
                    items: state.items,
                    onOpen: { onAction(.openSeries($0)) },
                    onToggleLibrary: { onAction(.removeSeries($0.id)) },
                    onLoadMore: {}
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .refreshable { await onRefresh() }
        .searchable(
            text: Binding(
                get: { state.searchText },
                set: { onAction(.searchTextChanged($0)) }),
            prompt: "Search Library"
        )
        .background(Palette.background)
        .navigationTitle("Library")
        .toolbar { filterToolbar }
        .safeAreaInset(edge: .top) {
            if let failure = state.removalFailure {
                FailureBanner(
                    title: "Couldn’t remove \(failure.title)",
                    message: failure.message,
                    retry: { onAction(.retryRemoval(failure.seriesID)) },
                    dismiss: { onAction(.dismissRemovalFailure) }
                )
                .padding(.horizontal, Spacing.screenMargin)
            }
        }
    }

    @ToolbarContentBuilder
    private var filterToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Picker(
                    "Content Type",
                    selection: Binding(
                        get: { state.contentFilter },
                        set: { onAction(.selectContentFilter($0)) }
                    )
                ) {
                    ForEach(LibraryContentFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }

                Picker(
                    "Source",
                    selection: Binding<Int64?>(
                        get: { state.selectedSourceID },
                        set: { onAction(.selectSource($0)) }
                    )
                ) {
                    Text("All Sources").tag(Int64?.none)
                    ForEach(state.sourceOptions) { source in
                        Text(source.name).tag(Optional(source.id))
                    }
                }
            } label: {
                Label("Filter Library", systemImage: filterSystemImage)
            }

            Menu {
                Picker(
                    "Sort Library",
                    selection: Binding(
                        get: { state.sort },
                        set: { onAction(.selectSort($0)) }
                    )
                ) {
                    ForEach(LibrarySort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
            } label: {
                Label("Sort Library", systemImage: "arrow.up.arrow.down")
            }
        }
    }

    private var filterSystemImage: String {
        state.hasActiveFilters
            ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
    }
}

#Preview("Populated library") {
    NavigationStack {
        LibraryContent(
            state: LibraryState(
                phase: .populated,
                items: [
                    SeriesCardItem(
                        series: Series(
                            sourceID: 1,
                            url: URL(string: "https://example.test/series/novel")!,
                            title: "The Long Road Home Through a Thousand Worlds",
                            contentType: .novel
                        ),
                        sourceName: "Novel Source",
                        isSaved: true
                    ),
                    SeriesCardItem(
                        series: Series(
                            sourceID: 2,
                            url: URL(string: "https://example.test/series/manhwa")!,
                            title: "The Swordmaster",
                            coverURL: URL(string: "https://example.invalid/cover.jpg"),
                            contentType: .manhwa
                        ),
                        sourceName: "Comic Source",
                        isSaved: true
                    )
                ],
                sourceOptions: [
                    LibrarySourceOption(id: 1, name: "Novel Source"),
                    LibrarySourceOption(id: 2, name: "Comic Source")
                ]
            ),
            onAction: { _ in }
        )
    }
}

#Preview("Library states") {
    TabView {
        LibraryContent(state: LibraryState(phase: .loading), onAction: { _ in })
            .tabItem { Text("Loading") }
        LibraryContent(state: LibraryState(phase: .empty), onAction: { _ in })
            .tabItem { Text("Empty") }
        LibraryContent(
            state: LibraryState(
                phase: .filteredEmpty,
                contentFilter: .manhwa
            ),
            onAction: { _ in }
        )
        .tabItem { Text("Filtered") }
        LibraryContent(
            state: LibraryState(phase: .error(message: "The library could not be read.")),
            onAction: { _ in }
        )
        .tabItem { Text("Error") }
    }
}
