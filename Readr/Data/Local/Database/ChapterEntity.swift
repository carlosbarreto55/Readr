import Foundation
import SwiftData

/// A chapter and the reader's progress through it, as stored.
///
/// A persistence type, never a domain type (invariant 12).
///
/// Read state lives here rather than in its own entity because progress has no
/// meaning without its chapter: the cascade from `SeriesEntity` collects it, and
/// a refresh merge reads and writes one row.
@Model
final class ChapterEntity {
    /// `"<sourceID>|<url>"`, derived by `EntityKey`. State follows this key, not
    /// list position, so a source that renumbers or reorders its chapters cannot
    /// move a reader's progress onto a different one.
    @Attribute(.unique) var key: String

    var sourceID: Int64
    var seriesURL: String
    var url: String
    var name: String
    var number: Double?
    var dateUploaded: Date?
    var scanlator: String?

    var isRead: Bool
    /// How far through the chapter the reader got, as a fraction from 0 to 1.
    var readingPosition: Double
    var lastReadAt: Date?

    var series: SeriesEntity?

    init(
        sourceID: Int64,
        seriesURL: String,
        url: String,
        name: String,
        number: Double? = nil,
        dateUploaded: Date? = nil,
        scanlator: String? = nil,
        isRead: Bool = false,
        readingPosition: Double = 0,
        lastReadAt: Date? = nil
    ) {
        self.key = EntityKey.identity(sourceID: sourceID, urlString: url)
        self.sourceID = sourceID
        self.seriesURL = seriesURL
        self.url = url
        self.name = name
        self.number = number
        self.dateUploaded = dateUploaded
        self.scanlator = scanlator
        self.isRead = isRead
        self.readingPosition = readingPosition
        self.lastReadAt = lastReadAt
    }
}
