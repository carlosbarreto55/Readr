import Foundation

/// The plugin boundary every supported site implements.
///
/// Transcribed from `architecture.md` §4.2. The app depends on this protocol, not
/// on concrete site types; changing it requires explicit human approval.
///
/// Implementations **throw** on failure. They do not log, do not catch and
/// continue, and do not return `nil` or empty sentinels in place of an error —
/// deciding what a failure means for the user is a repository's job, not a
/// source's. A reachable catalog page that parses but holds no entries is not a
/// failure: it returns `SeriesPage.empty`.
///
/// A plugin returns exactly one content shape: `.text(html:)` when `type` is
/// `.novel`, `.pages(imageURLs:)` when it is `.manhwa`, never both.
public protocol Source: Sendable {
    /// Produced by `computeSourceID(name:lang:type:)`, never a hand-picked literal.
    ///
    /// Every shipped plugin also carries a test asserting this value as a
    /// hardcoded literal. The `computeSourceID` guard rail pins the function; only
    /// a per-plugin test pins the plugin.
    var id: Int64 { get }

    /// **Frozen once shipped.** This is not a display string that happens to be
    /// hashed — it is one third of the key under which this site's entire library
    /// and every downloaded file is stored. Renaming it orphans all of them, with
    /// nothing crashing to say so.
    var name: String { get }

    /// **Frozen once shipped**, for the same reason as `name`.
    var lang: String { get }
    var baseURL: URL { get }
    var type: ContentType { get }

    func supports(_ filter: Filter) -> Bool
    func popular(page: Int) async throws -> SeriesPage
    func latest(page: Int) async throws -> SeriesPage
    func search(query: String, page: Int, filters: FilterList) async throws -> SeriesPage
    func seriesDetails(for series: Series) async throws -> Series
    func chapterList(for series: Series) async throws -> [Chapter]
    func chapterContent(for chapter: Chapter) async throws -> ChapterContent
}

extension Source {
    /// This source as the rest of the app sees it.
    ///
    /// Repositories hand this to presentation, which is why a presentation model
    /// never needs `SourceRegistry` or a concrete source type.
    public var info: SourceInfo {
        SourceInfo(id: id, name: name, lang: lang, baseURL: baseURL, contentType: type)
    }
}
