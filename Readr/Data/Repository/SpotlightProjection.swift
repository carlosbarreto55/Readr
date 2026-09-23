import Foundation

/// Keeps the Spotlight index a projection of the library.
///
/// A `LibraryChangeObserver`: every save — a Browse add, a detail refresh, a
/// title repair — re-indexes the series, and every removal deletes its item, so
/// the index follows metadata without any caller knowing it exists. Nothing here
/// can fail a library operation; index writes are fire-and-forget by contract.
///
/// Items are indexed at once with whatever thumbnail is cached, then any missing
/// cover is fetched off to the side and the item re-indexed — unless the series
/// was removed in the meantime, which would otherwise resurrect a stale item.
struct SpotlightProjection: LibraryChangeObserver {
    let indexer: any SeriesIndexing
    let thumbnails: SpotlightThumbnailCache
    let sourceName: @Sendable (Int64) -> String
    let loadCover: @Sendable (URL) async -> Data?
    let isSaved: @Sendable (SeriesID) async -> Bool

    func librarySaved(_ series: Series) async {
        await index([series])
    }

    func libraryRemoved(_ id: SeriesID) async {
        await remove([id])
    }

    /// Indexes series now; fetches missing thumbnails afterwards.
    ///
    /// - Returns: the thumbnail task, so a test can wait for it. Callers in the
    ///   app never do.
    @discardableResult
    func index(_ series: [Series]) async -> Task<Void, Never>? {
        await indexer.index(series.map { item(for: $0) })

        let missing = series.filter { $0.coverURL != nil && thumbnails.cached(for: $0.id) == nil }
        guard !missing.isEmpty else { return nil }
        let projection = self
        return Task.detached(priority: .utility) {
            for series in missing {
                if Task.isCancelled { return }
                guard let cover = series.coverURL, let data = await projection.loadCover(cover),
                    projection.thumbnails.store(data, for: series.id) != nil,
                    await projection.isSaved(series.id)
                else { continue }
                await projection.indexer.index([projection.item(for: series)])
            }
        }
    }

    func remove(_ ids: [SeriesID]) async {
        await indexer.remove(ids)
        for id in ids {
            thumbnails.remove(id)
        }
    }

    /// Replaces the index with exactly `series`.
    @discardableResult
    func rebuild(_ series: [Series]) async -> Task<Void, Never>? {
        await indexer.removeAll()
        return await index(series)
    }

    private func item(for series: Series) -> SpotlightAttributes.Item {
        SpotlightAttributes.Item(
            series: series,
            sourceName: sourceName(series.sourceID),
            thumbnailURL: thumbnails.cached(for: series.id))
    }
}
