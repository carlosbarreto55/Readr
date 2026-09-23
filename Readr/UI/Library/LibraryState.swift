import Foundation

enum LibraryContentFilter: String, CaseIterable, Sendable, Identifiable {
    case all
    case novel
    case manhwa

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All Types"
        case .novel: "Novels"
        case .manhwa: "Manhwa"
        }
    }

    func includes(_ contentType: ContentType) -> Bool {
        switch self {
        case .all: true
        case .novel: contentType == .novel
        case .manhwa: contentType == .manhwa
        }
    }
}

enum LibrarySort: String, CaseIterable, Sendable, Identifiable {
    case title
    case dateAdded
    case lastRead

    var id: String { rawValue }

    var title: String {
        switch self {
        case .title: "Title"
        case .dateAdded: "Date Added"
        case .lastRead: "Last Read"
        }
    }
}

struct LibrarySourceOption: Sendable, Identifiable, Hashable {
    let id: Int64
    let name: String
}

enum LibraryPhase: Sendable, Equatable {
    case loading
    case empty
    case error(message: String)
    case filteredEmpty
    /// Saved series exist, but none matches the search.
    case searchEmpty(query: String)
    case populated
}

struct LibraryRemovalFailure: Sendable, Equatable {
    let seriesID: SeriesID
    let title: String
    let message: String
}

struct LibraryState {
    var phase: LibraryPhase = .loading
    var items: [SeriesCardItem] = []
    var contentFilter: LibraryContentFilter = .all
    var selectedSourceID: Int64?
    var sourceOptions: [LibrarySourceOption] = []
    var sort: LibrarySort = .dateAdded
    var removalFailure: LibraryRemovalFailure?
    var searchText = ""

    var hasActiveFilters: Bool {
        contentFilter != .all || selectedSourceID != nil
    }
}

enum LibraryAction: Sendable {
    case appeared
    case retry
    case selectContentFilter(LibraryContentFilter)
    case selectSource(Int64?)
    case selectSort(LibrarySort)
    case clearFilters
    case searchTextChanged(String)
    case openSeries(SeriesID)
    case removeSeries(SeriesID)
    case retryRemoval(SeriesID)
    case dismissRemovalFailure
}

enum LibraryEffect: Sendable, Equatable {
    case openSeries(SeriesID)
}
