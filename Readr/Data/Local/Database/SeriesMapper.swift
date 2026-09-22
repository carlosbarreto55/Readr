import Foundation

/// Translates between `SeriesEntity` and the `Series` domain model.
///
/// Free functions rather than methods on the entity. A method on a `@Model` would
/// invite callers to reach for it from outside the repository, which is exactly
/// the boundary invariant 12 exists to hold.
enum SeriesMapper {

    /// - Returns: `nil` if the stored row cannot be expressed as a domain value,
    ///   which means its URL or content type was corrupted. Callers skip such a
    ///   row rather than failing the whole fetch.
    static func toDomain(_ entity: SeriesEntity) -> Series? {
        guard let url = URL(string: entity.url),
            let contentType = ContentType(rawValue: entity.contentTypeRaw)
        else {
            return nil
        }
        return Series(
            sourceID: entity.sourceID,
            url: url,
            title: entity.title,
            coverURL: entity.coverURL.flatMap(URL.init(string:)),
            synopsis: entity.synopsis,
            author: entity.author,
            artist: entity.artist,
            genres: entity.genres,
            // An unrecognized stored status degrades to `.unknown` rather than
            // discarding the row.
            status: SeriesStatus(rawValue: entity.statusRaw) ?? .unknown,
            contentType: contentType
        )
    }

    static func makeEntity(from series: Series, dateAdded: Date = .now) -> SeriesEntity {
        SeriesEntity(
            sourceID: series.sourceID,
            url: series.url.absoluteString,
            title: series.title,
            coverURL: series.coverURL?.absoluteString,
            synopsis: series.synopsis,
            author: series.author,
            artist: series.artist,
            genres: series.genres,
            statusRaw: series.status.rawValue,
            contentTypeRaw: series.contentType.rawValue,
            dateAdded: dateAdded
        )
    }

    /// Updates a stored row's metadata in place, leaving identity and the
    /// reader's own state — `dateAdded`, `lastReadAt`, chapters — untouched.
    static func apply(_ series: Series, to entity: SeriesEntity) {
        entity.title = series.title
        entity.coverURL = series.coverURL?.absoluteString
        entity.synopsis = series.synopsis
        entity.author = series.author
        entity.artist = series.artist
        entity.genres = series.genres
        entity.statusRaw = series.status.rawValue
        entity.contentTypeRaw = series.contentType.rawValue
    }
}
