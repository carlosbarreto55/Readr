import Foundation

/// A series' detail: the source's view of it folded into the library's.
///
/// The one contract that coordinates catalog and library for a single series, so
/// the detail screen never has to decide which of the two to trust — or write to
/// both and leave them disagreeing when the second write fails.
public protocol SeriesRepository: Sendable {

    /// The saved series and its stored chapters in reading order, or `nil` when
    /// the series is not saved. Local only: no network.
    func stored(_ id: SeriesID) async throws -> SeriesSnapshot?

    /// Something to show for `id` before its details arrive: the saved series,
    /// else the catalog's last listing of it, else a bare series carrying only
    /// its identity and its source's content type.
    ///
    /// - Throws: `CatalogRepositoryError.unknownSource` when the series is not
    ///   saved and no source is registered under its `sourceID`.
    func seed(for id: SeriesID) async throws -> Series

    /// Fetches details and chapters from the source, bypassing caches.
    ///
    /// A saved series has the enriched metadata saved and the chapter list merged
    /// by `LibraryRepository.mergeChapterList(_:for:)`, and the stored result is
    /// returned. An unsaved series is returned as fetched with unread chapters,
    /// and nothing is written.
    func refresh(_ series: Series) async throws -> SeriesSnapshot

    /// Refreshes every saved series: repairs a blank title from its source, then
    /// merges its chapter list. A series that fails is skipped, left as it was,
    /// and retried on the next refresh.
    func refreshLibrary() async -> LibraryRefreshReport
}

/// One series with its chapters, as the detail screen renders it.
public struct SeriesSnapshot: Sendable, Hashable {
    public let series: Series
    /// In reading order.
    public let chapters: [LibraryChapter]
    public let isSaved: Bool

    public init(series: Series, chapters: [LibraryChapter], isSaved: Bool) {
        self.series = series
        self.chapters = chapters
        self.isSaved = isSaved
    }
}

/// What a library refresh did.
public struct LibraryRefreshReport: Sendable, Hashable {
    public let refreshed: Int
    public let failed: Int
    /// Series whose blank title was replaced by a non-blank one.
    public let repairedTitles: Int

    public init(refreshed: Int, failed: Int, repairedTitles: Int) {
        self.refreshed = refreshed
        self.failed = failed
        self.repairedTitles = repairedTitles
    }
}
