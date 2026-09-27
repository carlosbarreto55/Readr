import SwiftUI

/// Stateless rendering for the source list and one selected source catalog.
struct BrowseContent: View {
    let state: BrowseState
    let onAction: (BrowseAction) -> Void

    var body: some View {
        Group {
            switch state.destination {
            case .sources:
                sourceList
            case .catalog:
                catalog
            }
        }
        .navigationTitle(state.navigationTitle)
    }

    @ViewBuilder
    private var sourceList: some View {
        if state.isLoading {
            ProgressView("Loading Sources")
        } else if state.sources.isEmpty {
            ContentUnavailableView {
                Label("No Sources", systemImage: "square.stack.3d.up.slash")
            } description: {
                Text("There are no registered sources to browse.")
            }
        } else {
            List(state.sources) { source in
                Button {
                    onAction(.sourceSelected(source.id))
                } label: {
                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                        Text(source.contentType.browseTitle)
                            .font(Typography.body)
                            .foregroundStyle(Palette.label)

                        Text("\(source.name) · \(source.lang.uppercased())")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.secondaryLabel)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens this source's catalog")
            }
        }
    }

    private var catalog: some View {
        VStack(spacing: .zero) {
            Picker(
                "Catalog",
                selection: Binding<BrowseCatalogSection?>(
                    get: { selectedSection },
                    set: { section in
                        switch section {
                        case .popular:
                            onAction(.showPopular)
                        case .latest:
                            onAction(.showLatest)
                        case nil:
                            break
                        }
                    }
                )
            ) {
                Text("Popular").tag(BrowseCatalogSection?.some(.popular))
                Text("Latest").tag(BrowseCatalogSection?.some(.latest))
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.vertical, Spacing.small)

            Divider()

            catalogBody
        }
        .searchable(
            text: Binding(
                get: { state.searchText },
                set: { onAction(.searchTextChanged($0)) }
            ),
            prompt: "Search series"
        )
        .onSubmit(of: .search) {
            onAction(.searchSubmitted)
        }
    }

    @ViewBuilder
    private var catalogBody: some View {
        if state.items.isEmpty, state.isLoading {
            ProgressView("Loading Catalog")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.items.isEmpty, let errorMessage = state.errorMessage {
            ContentUnavailableView {
                Label("Can't Load Catalog", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Retry") {
                    onAction(.retry)
                }
            }
        } else if state.items.isEmpty {
            ContentUnavailableView {
                Label(emptyTitle, systemImage: "books.vertical")
            } description: {
                Text(emptyDescription)
            }
        } else {
            SeriesCatalogGrid(
                items: state.items,
                onOpen: { onAction(.openSeries($0)) },
                onToggleLibrary: { onAction(.toggleLibrary($0)) },
                onLoadMore: { onAction(.loadMore) }
            )
            .safeAreaInset(edge: .bottom) {
                catalogFooter
            }
        }
    }

    @ViewBuilder
    private var catalogFooter: some View {
        if let membershipErrorMessage = state.membershipErrorMessage {
            VStack(alignment: .leading, spacing: Spacing.small) {
                Label(membershipErrorMessage, systemImage: "exclamationmark.triangle")
                    .font(Typography.caption)

                HStack {
                    Button("Retry") {
                        onAction(.retryMembership)
                    }
                    Button("Dismiss") {
                        onAction(.dismissMembershipError)
                    }
                }
                .font(Typography.caption)
            }
            .foregroundStyle(Palette.label)
            .padding(Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface)
        } else if let errorMessage = state.errorMessage {
            HStack(spacing: Spacing.medium) {
                Text(errorMessage)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.secondaryLabel)
                Spacer()
                Button("Retry") {
                    onAction(.retry)
                }
            }
            .padding(Spacing.medium)
            .background(Palette.surface)
        } else if state.isLoading {
            ProgressView()
                .padding(Spacing.medium)
                .frame(maxWidth: .infinity)
                .background(Palette.surface)
        }
    }

    private var selectedSection: BrowseCatalogSection? {
        switch state.request {
        case .popular:
            .popular
        case .latest:
            .latest
        case .search:
            nil
        }
    }

    private var emptyTitle: String {
        if case .search = state.request { "No Results" } else { "No Series" }
    }

    private var emptyDescription: String {
        if case .search(let query) = state.request {
            "No series matched “\(query)”."
        } else {
            "This catalog does not have any series yet."
        }
    }
}

private enum BrowseCatalogSection: Hashable {
    case popular
    case latest
}

#Preview("Sources") {
    NavigationStack {
        BrowseContent(
            state: BrowseState(
                destination: .sources,
                sources: BrowsePreview.sources,
                isLoading: false
            ),
            onAction: { _ in }
        )
    }
}

#Preview("Catalog") {
    NavigationStack {
        BrowseContent(
            state: BrowseState(
                destination: .catalog(sourceID: 1),
                sources: BrowsePreview.sources,
                selectedSource: BrowsePreview.sources[0],
                items: BrowsePreview.items,
                isLoading: false
            ),
            onAction: { _ in }
        )
    }
}

#Preview("Catalog error") {
    NavigationStack {
        BrowseContent(
            state: BrowseState(
                destination: .catalog(sourceID: 1),
                sources: BrowsePreview.sources,
                selectedSource: BrowsePreview.sources[0],
                isLoading: false,
                errorMessage: "The source could not be reached."
            ),
            onAction: { _ in }
        )
    }
}

private enum BrowsePreview {
    static let sources = [
        SourceInfo(
            id: 1,
            name: "FreeWebNovel",
            lang: "en",
            baseURL: URL(string: "https://example.test")!,
            contentType: .novel
        ),
        SourceInfo(
            id: 2,
            name: "AsuraScans",
            lang: "en",
            baseURL: URL(string: "https://example.test")!,
            contentType: .manhwa
        )
    ]

    static let items = (1...6).map { index in
        SeriesCardItem(
            series: Series(
                sourceID: 1,
                url: URL(string: "https://example.test/series/\(index)")!,
                title: index.isMultiple(of: 2)
                    ? "A Long Series Title That Wraps at Larger Text Sizes"
                    : "Series \(index)",
                contentType: .novel
            ),
            sourceName: "FreeWebNovel",
            isSaved: index.isMultiple(of: 3)
        )
    }
}
