import Foundation

/// Which half of Browse is being rendered by this screen instance.
enum BrowseDestination: Sendable, Equatable {
    case sources
    case catalog(sourceID: Int64)
}

/// The remote listing currently shown inside a source catalog.
enum BrowseCatalogRequest: Sendable, Equatable {
    case popular
    case latest
    case search(query: String)
}

/// Renderable state for both the Browse source list and a selected catalog.
struct BrowseState: Sendable {
    let destination: BrowseDestination
    var sources: [SourceInfo] = []
    var selectedSource: SourceInfo?
    var request: BrowseCatalogRequest = .popular
    var searchText = ""
    var items: [SeriesCardItem] = []
    var isLoading = true
    var hasMore = false
    var errorMessage: String?
    var membershipErrorMessage: String?

    var navigationTitle: String {
        switch destination {
        case .sources:
            "Browse"
        case .catalog:
            selectedSource?.name ?? "Catalog"
        }
    }
}

/// User intent forwarded from the stateless content view.
enum BrowseAction: Sendable {
    case appeared
    case sourceSelected(Int64)
    case showPopular
    case showLatest
    case searchTextChanged(String)
    case searchSubmitted
    case retry
    case loadMore
    case openSeries(SeriesID)
    case toggleLibrary(Series)
    case refreshMembership
    case retryMembership
    case dismissMembershipError
}

/// Work owned by the screen rather than stored as presentation state.
enum BrowseEffect: Sendable, Equatable {
    case openSource(Int64)
    case openSeries(SeriesID)
}
