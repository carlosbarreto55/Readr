import Foundation

/// `CatalogRepository` over `SourceRegistry`, with the metadata caches in front.
///
/// Deciding *whether to fetch* is orchestration, which `architecture.md` §8 puts
/// in a repository rather than in a source. The practical effect is that a plugin
/// cannot forget to cache and cannot cache wrongly: it is never asked to.
///
/// Three caches rather than one, because the things they hold go stale at
/// different rates. A single lifetime would either re-fetch series details that
/// change a few times a year, or serve a two-hour-old chapter list to a reader
/// waiting for today's chapter.
actor DefaultCatalogRepository: CatalogRepository {

    private let registry: SourceRegistry
    private let pageCache: SourceMetadataCache<SeriesPage>
    private let detailCache: SourceMetadataCache<Series>
    private let chapterCache: SourceMetadataCache<[Chapter]>

    /// The latest listing of every series a page has returned, for
    /// `knownSeries(_:)`. Bounded: a miss only costs the detail screen its
    /// pre-detail title and cover.
    private var known: [SeriesID: Series] = [:]
    private var knownOrder: [SeriesID] = []
    private let knownLimit: Int

    /// - Note: the lifetimes are carried over from the app Readr descends from,
    ///   where they were not visibly tuned. Nothing in `source-metadata-cache`
    ///   fixes a number — only that an expiry exists — so they are stated in one
    ///   place and revisited once there is real browsing to measure.
    init(
        registry: SourceRegistry,
        pageCache: SourceMetadataCache<SeriesPage> = .init(
            maxEntries: 100, lifetime: .seconds(300)),
        detailCache: SourceMetadataCache<Series> = .init(
            maxEntries: 50, lifetime: .seconds(900)),
        chapterCache: SourceMetadataCache<[Chapter]> = .init(
            maxEntries: 20, lifetime: .seconds(120)),
        knownLimit: Int = 500
    ) {
        self.knownLimit = knownLimit
        self.registry = registry
        self.pageCache = pageCache
        self.detailCache = detailCache
        self.chapterCache = chapterCache
    }

    func sources() async -> [SourceInfo] { registry.infos }

    func supports(_ filter: Filter, sourceID: Int64) async -> Bool {
        registry[sourceID]?.supports(filter) ?? false
    }

    func popular(sourceID: Int64, page: Int, refresh: Bool) async throws -> SeriesPage {
        let source = try source(sourceID)
        return try await remembering(
            cached(
                key: SourceCacheKey.popular(sourceID: sourceID, page: page),
                in: pageCache,
                refresh: refresh
            ) {
                try await source.popular(page: page)
            })
    }

    func latest(sourceID: Int64, page: Int, refresh: Bool) async throws -> SeriesPage {
        let source = try source(sourceID)
        return try await remembering(
            cached(
                key: SourceCacheKey.latest(sourceID: sourceID, page: page),
                in: pageCache,
                refresh: refresh
            ) {
                try await source.latest(page: page)
            })
    }

    func search(
        sourceID: Int64,
        query: String,
        page: Int,
        filters: FilterList,
        refresh: Bool
    ) async throws -> SeriesPage {
        let source = try source(sourceID)
        return try await remembering(
            cached(
                key: SourceCacheKey.search(
                    sourceID: sourceID, query: query, page: page, filters: filters),
                in: pageCache,
                refresh: refresh
            ) {
                try await source.search(query: query, page: page, filters: filters)
            })
    }

    func details(for series: Series, refresh: Bool) async throws -> Series {
        let source = try source(series.sourceID)
        return try await cached(
            key: SourceCacheKey.details(for: series),
            in: detailCache,
            refresh: refresh
        ) {
            try await source.seriesDetails(for: series)
        }
    }

    func chapters(for series: Series, refresh: Bool) async throws -> [Chapter] {
        let source = try source(series.sourceID)
        return try await cached(
            key: SourceCacheKey.chapters(sourceID: series.sourceID, url: series.url),
            in: chapterCache,
            refresh: refresh
        ) {
            try await source.chapterList(for: series)
        }
    }

    func knownSeries(_ id: SeriesID) async -> Series? {
        known[id]
    }

    /// Records every entry of a returned page, newest listing winning.
    private func remembering(_ page: SeriesPage) -> SeriesPage {
        for series in page.entries {
            let isNew = known.updateValue(series, forKey: series.id) == nil
            if isNew { knownOrder.append(series.id) }
        }
        if knownOrder.count > knownLimit {
            let overflow = knownOrder.count - knownLimit
            for id in knownOrder.prefix(overflow) {
                known[id] = nil
            }
            knownOrder.removeFirst(overflow)
        }
        return page
    }

    func clearCaches() async {
        await pageCache.removeAll()
        await detailCache.removeAll()
        await chapterCache.removeAll()
    }

    private func source(_ id: Int64) throws -> any Source {
        guard let source = registry[id] else {
            throw CatalogRepositoryError.unknownSource(id)
        }
        return source
    }

    /// Reads through the cache unless `refresh`, then stores the result.
    ///
    /// A refresh does not read the cache *and* overwrites the entry it bypassed,
    /// so a freshly fetched value cannot be shadowed afterwards by the stale one
    /// it was fetched to replace.
    ///
    /// A throw stores nothing. Caching a failure would turn one bad response into
    /// several minutes of a catalog that refuses to load with no way to retry.
    private func cached<Value: Sendable>(
        key: String,
        in cache: SourceMetadataCache<Value>,
        refresh: Bool,
        load: () async throws -> Value
    ) async rethrows -> Value {
        if !refresh, let hit = await cache.value(for: key) {
            return hit
        }
        let loadID = await cache.beginLoad(for: key)
        do {
            let value = try await load()
            await cache.storeIfLatest(value, for: key, loadID: loadID)
            return value
        } catch {
            await cache.finishLoad(for: key, loadID: loadID)
            throw error
        }
    }
}
