import Foundation

/// The app's four top-level destinations.
public enum AppTab: String, Sendable, Hashable, CaseIterable, Identifiable {
    case library
    case browse
    case downloads
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .library: "Library"
        case .browse: "Browse"
        case .downloads: "Downloads"
        case .settings: "Settings"
        }
    }

    public var systemImage: String {
        switch self {
        case .library: "books.vertical"
        case .browse: "square.grid.2x2"
        case .downloads: "arrow.down.circle"
        case .settings: "gearshape"
        }
    }
}

// Each tab gets its own route type rather than sharing one app-wide enum. A
// shared type would let any destination push any other, which is how a tab shell
// decays into implicit global navigation.
//
// Cases carry `(sourceID, url)` — via `SeriesID` — rather than a whole `Series`,
// so a route stays cheap to compare and cannot go stale against refreshed
// metadata.

/// Destinations reachable from the Library tab.
public enum LibraryRoute: Sendable, Hashable {
    case series(SeriesID)
}

/// Destinations reachable from the Browse tab.
public enum BrowseRoute: Sendable, Hashable {
    /// One source's catalog.
    case catalog(sourceID: Int64)
    case series(SeriesID)
}

/// Destinations reachable from the Downloads tab.
public enum DownloadsRoute: Sendable, Hashable {
    case series(SeriesID)
}

/// Destinations reachable from the Settings tab.
public enum SettingsRoute: Sendable, Hashable {
    case sources
    case reader
    case storage
}

/// Everything the Reader needs to open a chapter.
///
/// The Reader is presented outside the tab chrome rather than pushed onto a path,
/// so this is not a case of any tab's route enum. It carries the content type
/// alongside the identifiers because the Reader must be able to tell that a loaded
/// payload disagrees with what the route promised.
///
/// The Reader itself is built in a later change; this is the value it will be
/// presented with.
public struct ReaderRoute: Sendable, Hashable, Identifiable {
    public let sourceID: Int64
    public let seriesURL: URL
    public let chapterURL: URL
    public let contentType: ContentType

    public init(sourceID: Int64, seriesURL: URL, chapterURL: URL, contentType: ContentType) {
        self.sourceID = sourceID
        self.seriesURL = seriesURL
        self.chapterURL = chapterURL
        self.contentType = contentType
    }

    public var id: ChapterID { ChapterID(sourceID: sourceID, url: chapterURL) }
}
