/// Publication status as reported by a source.
///
/// `unknown` is the documented landing place for a status a source does not
/// recognize — an unrecognized status degrades rather than failing the fetch.
public enum SeriesStatus: String, Sendable, Hashable, CaseIterable, Codable {
    case ongoing
    case completed
    case hiatus
    case cancelled
    case unknown
}
