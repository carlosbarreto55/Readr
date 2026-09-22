import Foundation

/// A series as a source describes it.
///
/// Identity is `(sourceID, url)`. Equality and hashing are defined on that pair
/// alone, so a series refreshed with new metadata remains the same series.
public struct Series: Sendable, Identifiable, Hashable, Codable {
    public let sourceID: Int64
    public let url: URL
    public let title: String
    public let coverURL: URL?
    public let synopsis: String?
    public let author: String?
    public let artist: String?
    public let genres: [String]
    public let status: SeriesStatus
    public let contentType: ContentType

    public init(
        sourceID: Int64,
        url: URL,
        title: String,
        coverURL: URL? = nil,
        synopsis: String? = nil,
        author: String? = nil,
        artist: String? = nil,
        genres: [String] = [],
        status: SeriesStatus = .unknown,
        contentType: ContentType
    ) {
        self.sourceID = sourceID
        self.url = url
        self.title = title
        self.coverURL = coverURL
        self.synopsis = synopsis
        self.author = author
        self.artist = artist
        self.genres = genres
        self.status = status
        self.contentType = contentType
    }

    /// The stable identity of this series: `(sourceID, url)`.
    public var id: SeriesID { SeriesID(sourceID: sourceID, url: url) }

    public static func == (lhs: Series, rhs: Series) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// The `(sourceID, url)` pair that identifies a series everywhere it is stored.
///
/// `Hasher` is fine here: this is an in-memory identity, never a persisted key.
/// The persisted half — `sourceID` itself — is produced by `computeSourceID`.
public struct SeriesID: Sendable, Hashable, Codable {
    public let sourceID: Int64
    public let url: URL

    public init(sourceID: Int64, url: URL) {
        self.sourceID = sourceID
        self.url = url
    }
}
