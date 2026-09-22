/// A catalog filter a source may or may not support.
///
/// Deliberately minimal: only what the `Source` signature forces. The first real
/// catalog decides whether more is needed.
public enum Filter: Sendable, Hashable, Codable {
    /// Restrict results to a named genre.
    case genre(String)
    /// Restrict results to a publication status.
    case status(SeriesStatus)
    /// Order results by a source-defined sort key.
    case sort(String)
}

/// The filters applied to one catalog request.
public struct FilterList: Sendable, Hashable, Codable, ExpressibleByArrayLiteral {
    public let filters: [Filter]

    public init(_ filters: [Filter] = []) {
        self.filters = filters
    }

    public init(arrayLiteral elements: Filter...) {
        self.filters = elements
    }

    /// No filters applied.
    public static let none = FilterList()

    public var isEmpty: Bool { filters.isEmpty }
}
