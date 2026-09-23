import Foundation
import SwiftData

/// The first released schema, frozen.
///
/// An existing version is never edited in place. A model change introduces a new
/// `VersionedSchema` and a corresponding stage in `ReadrMigrationPlan` — see the
/// `schema-migration` capability. These classes are exactly the models v1 shipped
/// with, kept so the plan can recognize a v1 store and migrate it; nothing outside
/// migration and its tests refers to them.
///
/// Entity names are the unqualified class names, which is why the frozen copies
/// keep the names the store on disk already uses.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [SeriesEntity.self, ChapterEntity.self]
    }

    @Model
    final class SeriesEntity {
        @Attribute(.unique) var key: String

        var sourceID: Int64
        var url: String
        var title: String
        var coverURL: String?
        var synopsis: String?
        var author: String?
        var artist: String?
        var genres: [String]
        var statusRaw: String
        var contentTypeRaw: String
        var dateAdded: Date
        var lastReadAt: Date?

        @Relationship(deleteRule: .cascade, inverse: \ChapterEntity.series)
        var chapters: [ChapterEntity]

        init(
            sourceID: Int64,
            url: String,
            title: String,
            statusRaw: String,
            contentTypeRaw: String,
            dateAdded: Date = .now
        ) {
            self.key = EntityKey.identity(sourceID: sourceID, urlString: url)
            self.sourceID = sourceID
            self.url = url
            self.title = title
            self.genres = []
            self.statusRaw = statusRaw
            self.contentTypeRaw = contentTypeRaw
            self.dateAdded = dateAdded
            self.chapters = []
        }
    }

    @Model
    final class ChapterEntity {
        @Attribute(.unique) var key: String

        var sourceID: Int64
        var seriesURL: String
        var url: String
        var name: String
        var number: Double?
        var dateUploaded: Date?
        var scanlator: String?
        var isRead: Bool
        var readingPosition: Double
        var lastReadAt: Date?

        var series: SeriesEntity?

        init(sourceID: Int64, seriesURL: String, url: String, name: String, number: Double? = nil) {
            self.key = EntityKey.identity(sourceID: sourceID, urlString: url)
            self.sourceID = sourceID
            self.seriesURL = seriesURL
            self.url = url
            self.name = name
            self.number = number
            self.isRead = false
            self.readingPosition = 0
        }
    }
}
