import Foundation

/// A chapter as a source describes it.
///
/// Identity is `(sourceID, url)`, which is why refreshing a chapter list follows
/// identity rather than list position — a source that renumbers or reorders its
/// chapters must not move read state between them.
public struct Chapter: Sendable, Identifiable, Hashable, Codable {
    public let sourceID: Int64
    public let seriesURL: URL
    public let url: URL
    public let name: String
    public let number: Double?
    public let dateUploaded: Date?
    public let scanlator: String?

    public init(
        sourceID: Int64,
        seriesURL: URL,
        url: URL,
        name: String,
        number: Double? = nil,
        dateUploaded: Date? = nil,
        scanlator: String? = nil
    ) {
        self.sourceID = sourceID
        self.seriesURL = seriesURL
        self.url = url
        self.name = name
        self.number = number
        self.dateUploaded = dateUploaded
        self.scanlator = scanlator
    }

    /// The stable identity of this chapter: `(sourceID, url)`.
    public var id: ChapterID { ChapterID(sourceID: sourceID, url: url) }

    public static func == (lhs: Chapter, rhs: Chapter) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// The `(sourceID, url)` pair that identifies a chapter everywhere it is stored.
public struct ChapterID: Sendable, Hashable, Codable {
    public let sourceID: Int64
    public let url: URL

    public init(sourceID: Int64, url: URL) {
        self.sourceID = sourceID
        self.url = url
    }
}
