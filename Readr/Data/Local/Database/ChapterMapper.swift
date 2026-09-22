import Foundation

/// Translates between `ChapterEntity` and the `Chapter` domain model.
///
/// Free functions, for the same reason as `SeriesMapper`.
enum ChapterMapper {

    /// - Returns: `nil` if the stored row's URLs cannot be read back.
    static func toDomain(_ entity: ChapterEntity) -> Chapter? {
        guard let url = URL(string: entity.url),
            let seriesURL = URL(string: entity.seriesURL)
        else {
            return nil
        }
        return Chapter(
            sourceID: entity.sourceID,
            seriesURL: seriesURL,
            url: url,
            name: entity.name,
            number: entity.number,
            dateUploaded: entity.dateUploaded,
            scanlator: entity.scanlator
        )
    }

    static func makeEntity(from chapter: Chapter) -> ChapterEntity {
        ChapterEntity(
            sourceID: chapter.sourceID,
            seriesURL: chapter.seriesURL.absoluteString,
            url: chapter.url.absoluteString,
            name: chapter.name,
            number: chapter.number,
            dateUploaded: chapter.dateUploaded,
            scanlator: chapter.scanlator
        )
    }

    /// Updates a stored row's remote metadata in place, leaving the reader's own
    /// state — `isRead`, `readingPosition`, `lastReadAt` — untouched. This is what
    /// lets a chapter-list refresh update metadata without discarding progress.
    static func apply(_ chapter: Chapter, to entity: ChapterEntity) {
        entity.name = chapter.name
        entity.number = chapter.number
        entity.dateUploaded = chapter.dateUploaded
        entity.scanlator = chapter.scanlator
    }
}
