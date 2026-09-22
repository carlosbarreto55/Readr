import Foundation

/// Builds the key a source request is cached under.
///
/// One place, because two requests that differ must never collide onto one key —
/// a collision serves one catalog's results under another's query, which looks
/// like a parser bug and is not one.
///
/// Every variable-length part is written length-prefixed as `<count>:<value>`.
/// Without that, `"ab" + "c"` and `"a" + "bc"` produce the same string, so two
/// genuinely different filter sets would share a cache entry.
enum SourceCacheKey {

    static func popular(sourceID: Int64, page: Int) -> String {
        "\(sourceID):popular:\(page)"
    }

    static func latest(sourceID: Int64, page: Int) -> String {
        "\(sourceID):latest:\(page)"
    }

    static func search(
        sourceID: Int64,
        query: String,
        page: Int,
        filters: FilterList
    ) -> String {
        return "\(sourceID):search:\(page):"
            + prefixed(query)
            + ":"
            + prefixed(snapshot(filters))
    }

    /// Includes all input metadata because detail fetching enriches the exact
    /// catalog value supplied. Equal identity does not make two such requests
    /// interchangeable when one carries richer known fields.
    static func details(for series: Series) -> String {
        let genres = series.genres.map(prefixed).joined(separator: ",")
        let metadata = [
            prefixed(series.title),
            optional(series.coverURL?.absoluteString),
            optional(series.synopsis),
            optional(series.author),
            optional(series.artist),
            prefixed(genres),
            prefixed(series.status.rawValue),
            prefixed(series.contentType.rawValue)
        ].joined(separator: ":")
        return "\(series.sourceID):details:"
            + prefixed(series.url.absoluteString)
            + ":"
            + prefixed(metadata)
    }

    static func chapters(sourceID: Int64, url: URL) -> String {
        "\(sourceID):chapters:" + prefixed(url.absoluteString)
    }

    /// Preserves order because interpreting filters belongs to each site. The
    /// cache cannot assume differently ordered requests are interchangeable.
    private static func snapshot(_ filters: FilterList) -> String {
        filters.filters.map(describe).joined(separator: "\u{1f}")
    }

    private static func describe(_ filter: Filter) -> String {
        switch filter {
        case .genre(let value):
            return "genre:" + prefixed(value)
        case .status(let value):
            return "status:" + prefixed(value.rawValue)
        case .sort(let value):
            return "sort:" + prefixed(value)
        }
    }

    private static func prefixed(_ value: String) -> String {
        "\(value.count):\(value)"
    }

    private static func optional(_ value: String?) -> String {
        guard let value else { return "nil" }
        return "some:" + prefixed(value)
    }
}
