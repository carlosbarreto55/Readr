import Foundation

/// Remote catalog data, from whichever source publishes it.
///
/// Domain values in and out. It names no `Source`, no `SourceRegistry`, and no
/// cache, which is what lets a presentation model hold one and still satisfy
/// invariant 3.
///
/// Every method takes `refresh`. `source-metadata-cache` requires a
/// user-initiated refresh to bypass the cache, and making it a parameter of every
/// call — rather than a separate set of methods, or a mode on the repository —
/// means a caller states which one it wants at the point it asks.
public protocol CatalogRepository: Sendable {

    /// Sources available to browse.
    func sources() async -> [SourceInfo]

    /// One page of a source's popular listing, 1-based.
    ///
    /// - Throws: `CatalogRepositoryError.unknownSource` if nothing is registered
    ///   under `sourceID`, or whatever the source threw.
    func popular(sourceID: Int64, page: Int, refresh: Bool) async throws -> SeriesPage

    /// One page of a source's latest-updates listing, 1-based.
    func latest(sourceID: Int64, page: Int, refresh: Bool) async throws -> SeriesPage

    /// One page of search results, 1-based.
    func search(
        sourceID: Int64,
        query: String,
        page: Int,
        filters: FilterList,
        refresh: Bool
    ) async throws -> SeriesPage

    /// `series` enriched with its detail page.
    ///
    /// The returned series has the same `(sourceID, url)`, and a field the detail
    /// page omits keeps the value `series` already carried.
    func details(for series: Series, refresh: Bool) async throws -> Series

    /// A series' chapters as the source lists them, in source order.
    func chapters(for series: Series, refresh: Bool) async throws -> [Chapter]

    /// A chapter's content, from its source. Never cached: a chapter body is
    /// large and read once, and the Reader's forced re-fetch must reach the site.
    func chapterContent(for chapter: Chapter) async throws -> ChapterContent

    /// The series as the most recent catalog page listing it described it, or
    /// `nil` if no page this session has listed it.
    ///
    /// Lets a destination that received only an identity show a title and cover
    /// before its details arrive, without the route carrying a `Series` that could
    /// go stale.
    func knownSeries(_ id: SeriesID) async -> Series?

    /// Whether a source supports a filter at all, so a surface can offer only
    /// what will be honored.
    func supports(_ filter: Filter, sourceID: Int64) async -> Bool

    /// Empties the in-memory caches. Stored library data is untouched.
    func clearCaches() async
}

/// What a catalog operation can fail with.
public enum CatalogRepositoryError: Error, Equatable, Sendable {
    /// No source is registered under this identifier.
    ///
    /// A composition-time error surfacing at runtime — a stored series whose
    /// plugin was removed, most likely. It throws rather than returning empty so
    /// that "this source is gone" is distinguishable from "this source has
    /// nothing", which the reader would otherwise have to guess at.
    case unknownSource(Int64)
}
