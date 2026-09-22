import Foundation
import SwiftData

/// A saved series, as stored.
///
/// A persistence type, never a domain type (invariant 12). It does not leave
/// `Data/`; repositories translate it to and from `Series` through
/// `SeriesMapper`.
///
/// Presence means membership: a row exists only for a series the reader saved, so
/// there is no unsaved row needing a flag to hide it.
@Model
final class SeriesEntity {
    /// `"<sourceID>|<url>"`, derived by `EntityKey`. SwiftData has no composite
    /// unique constraint, so this is how `(sourceID, url)` identity is enforced
    /// by the store rather than by convention.
    @Attribute(.unique) var key: String

    var sourceID: Int64
    var url: String
    var title: String
    var coverURL: String?
    var synopsis: String?
    var author: String?
    var artist: String?
    var genres: [String]

    /// Stored as the enum's raw value rather than as the enum, so a case rename
    /// cannot silently reinterpret existing rows.
    var statusRaw: String
    var contentTypeRaw: String

    var dateAdded: Date
    var lastReadAt: Date?

    /// Removing a series takes its chapters and their read state with it, which
    /// is what `library-browse-catalog` requires.
    @Relationship(deleteRule: .cascade, inverse: \ChapterEntity.series)
    var chapters: [ChapterEntity]

    init(
        sourceID: Int64,
        url: String,
        title: String,
        coverURL: String? = nil,
        synopsis: String? = nil,
        author: String? = nil,
        artist: String? = nil,
        genres: [String] = [],
        statusRaw: String,
        contentTypeRaw: String,
        dateAdded: Date = .now,
        lastReadAt: Date? = nil
    ) {
        self.key = EntityKey.identity(sourceID: sourceID, urlString: url)
        self.sourceID = sourceID
        self.url = url
        self.title = title
        self.coverURL = coverURL
        self.synopsis = synopsis
        self.author = author
        self.artist = artist
        self.genres = genres
        self.statusRaw = statusRaw
        self.contentTypeRaw = contentTypeRaw
        self.dateAdded = dateAdded
        self.lastReadAt = lastReadAt
        self.chapters = []
    }
}
