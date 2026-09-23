import Foundation
import SwiftData

/// Adds the download queue.
///
/// Series and chapter models are unchanged from v2, so this version lists v2's
/// classes rather than copying them; `DownloadEntity` is new.
enum SchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [SeriesEntity.self, ChapterEntity.self, DownloadEntity.self]
    }

    typealias SeriesEntity = SchemaV2.SeriesEntity
    typealias ChapterEntity = SchemaV2.ChapterEntity

    /// A chapter queued for download, or stored.
    ///
    /// A persistence type, never a domain type (invariant 12). Deliberately
    /// unrelated to `SeriesEntity` and `ChapterEntity`: a chapter of a series
    /// outside the library can be downloaded, and a chapter-list refresh cannot
    /// reach download state at all — which is how refresh preserves it.
    @Model
    final class DownloadEntity {
        /// The chapter's `"<sourceID>|<url>"`, from `EntityKey`.
        @Attribute(.unique) var key: String

        var sourceID: Int64
        var seriesURL: String
        var chapterURL: String
        var chapterName: String
        var chapterNumber: Double?
        var seriesTitle: String
        var contentTypeRaw: String

        /// `pending`, `downloading`, `completed`, or `failed`.
        var stateRaw: String
        var errorMessage: String?
        var isRetryable: Bool
        var enqueuedAt: Date
        /// Monotonic across the store: the drain order.
        var sequence: Int64
        var byteCount: Int64

        init(
            sourceID: Int64,
            seriesURL: String,
            chapterURL: String,
            chapterName: String,
            chapterNumber: Double?,
            seriesTitle: String,
            contentTypeRaw: String,
            enqueuedAt: Date,
            sequence: Int64
        ) {
            self.key = EntityKey.identity(sourceID: sourceID, urlString: chapterURL)
            self.sourceID = sourceID
            self.seriesURL = seriesURL
            self.chapterURL = chapterURL
            self.chapterName = chapterName
            self.chapterNumber = chapterNumber
            self.seriesTitle = seriesTitle
            self.contentTypeRaw = contentTypeRaw
            self.stateRaw = DownloadStateRaw.pending.rawValue
            self.isRetryable = true
            self.enqueuedAt = enqueuedAt
            self.sequence = sequence
            self.byteCount = 0
        }
    }
}

/// The current version of the stored download model.
typealias DownloadEntity = CurrentSchema.DownloadEntity

/// Stored download states, by raw value so a case rename cannot reinterpret rows.
enum DownloadStateRaw: String {
    case pending
    case downloading
    case completed
    case failed
}
