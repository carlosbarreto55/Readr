import CoreSpotlight
import Foundation

/// Writes the Spotlight projection of the library.
///
/// A protocol so the projection's rules are tested without the system index.
/// Nothing here throws: an index write that fails must not fail — or even be
/// reported by — the library operation that caused it.
protocol SeriesIndexing: Sendable {
    func index(_ items: [SpotlightAttributes.Item]) async
    func remove(_ ids: [SeriesID]) async
    func removeAll() async
}

/// `SeriesIndexing` over the app's Core Spotlight index.
struct SpotlightIndexer: SeriesIndexing {
    static let domain = "dev.opus.readr.series"

    func index(_ items: [SpotlightAttributes.Item]) async {
        guard !items.isEmpty, CSSearchableIndex.isIndexingAvailable() else { return }
        let searchable = items.map {
            SpotlightAttributes.searchableItem(for: $0, domain: Self.domain)
        }
        try? await CSSearchableIndex.default().indexSearchableItems(searchable)
    }

    func remove(_ ids: [SeriesID]) async {
        guard !ids.isEmpty, CSSearchableIndex.isIndexingAvailable() else { return }
        try? await CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: ids.map(SpotlightIdentifier.make(for:)))
    }

    func removeAll() async {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        try? await CSSearchableIndex.default().deleteSearchableItems(
            withDomainIdentifiers: [Self.domain])
    }
}
