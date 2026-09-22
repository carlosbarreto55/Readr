/// One page of catalog results.
///
/// A reachable page that parses but holds no entries is an empty `SeriesPage`
/// with `hasMore == false`, not an error — empty is not a failure.
public struct SeriesPage: Sendable, Hashable, Codable {
    public let entries: [Series]
    public let hasMore: Bool

    public init(entries: [Series], hasMore: Bool) {
        self.entries = entries
        self.hasMore = hasMore
    }

    /// A reachable catalog page that legitimately contains nothing.
    public static let empty = SeriesPage(entries: [], hasMore: false)
}
