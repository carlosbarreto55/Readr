import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

/// A saved series as Spotlight shows it.
///
/// Series-level metadata only. Chapter text and page images are never indexed
/// (`spotlight-indexable-series`) — nothing here can reach them.
enum SpotlightAttributes {

    /// What one indexed series carries.
    struct Item: Sendable, Equatable {
        let id: SeriesID
        /// `Series.displayTitle`: never empty, even for a blank-titled series.
        let title: String
        let sourceName: String
        let author: String?
        let genres: [String]
        let synopsis: String?
        /// A local file; Spotlight does not fetch remote thumbnails.
        let thumbnailURL: URL?

        init(series: Series, sourceName: String, thumbnailURL: URL? = nil) {
            self.id = series.id
            self.title = series.displayTitle
            self.sourceName = sourceName
            self.author = series.author
            self.genres = series.genres
            self.synopsis = series.synopsis
            self.thumbnailURL = thumbnailURL
        }
    }

    static func attributeSet(for item: Item) -> CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = item.title
        attributes.displayName = item.title
        attributes.contentDescription = item.synopsis ?? item.sourceName
        attributes.keywords = [item.sourceName] + item.genres + [item.author].compactMap { $0 }
        if let author = item.author {
            attributes.creator = author
        }
        attributes.thumbnailURL = item.thumbnailURL
        return attributes
    }

    static func searchableItem(for item: Item, domain: String) -> CSSearchableItem {
        let searchable = CSSearchableItem(
            uniqueIdentifier: SpotlightIdentifier.make(for: item.id),
            domainIdentifier: domain,
            attributeSet: attributeSet(for: item))
        // Library membership, not a cache: kept until the series is removed.
        searchable.expirationDate = .distantFuture
        return searchable
    }
}
