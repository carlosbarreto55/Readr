import Foundation

/// A saved series together with metadata owned by the reader's library.
///
/// The timestamps describe local library state, not facts published by a
/// source, so they live beside `Series` rather than on it. Identity remains the
/// series' `(sourceID, url)` pair.
public struct LibraryItem: Sendable, Identifiable, Hashable {
    public let series: Series
    public let dateAdded: Date
    public let lastReadAt: Date?

    public init(series: Series, dateAdded: Date, lastReadAt: Date? = nil) {
        self.series = series
        self.dateAdded = dateAdded
        self.lastReadAt = lastReadAt
    }

    public var id: SeriesID { series.id }

    public static func == (lhs: LibraryItem, rhs: LibraryItem) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
