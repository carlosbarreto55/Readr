import Foundation
import Testing

@testable import Readr

/// Counts what actually reached the source. "Did not hit the network" is the
/// entire point of a cache, and the only way to assert it is to count.
private final class CountingSource: Source, @unchecked Sendable {
    let id: Int64
    let name = "Counting"
    let lang = "en"
    let baseURL = URL(string: "https://example.test")!
    let type = ContentType.novel

    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    private var failure: (any Error)?

    init(id: Int64 = 7) { self.id = id }

    func callCount(_ operation: String) -> Int { lock.withLock { counts[operation] ?? 0 } }
    func failNext(with error: any Error) { lock.withLock { failure = error } }

    private func record(_ operation: String) throws {
        try lock.withLock {
            counts[operation, default: 0] += 1
            if let error = failure {
                failure = nil
                throw error
            }
        }
    }

    func supports(_ filter: Filter) -> Bool {
        if case .genre = filter { return true }
        return false
    }

    func popular(page: Int) async throws -> SeriesPage {
        try record("popular")
        return SeriesPage(entries: [makeSeries("popular-\(page)")], hasMore: false)
    }

    func latest(page: Int) async throws -> SeriesPage {
        try record("latest")
        return SeriesPage(entries: [makeSeries("latest-\(page)")], hasMore: false)
    }

    func search(query: String, page: Int, filters: FilterList) async throws -> SeriesPage {
        try record("search")
        return SeriesPage(entries: [makeSeries("search-\(query)")], hasMore: false)
    }

    func seriesDetails(for series: Series) async throws -> Series {
        try record("details")
        return series.enriched(
            with: Series(
                sourceID: id, url: series.url, title: series.title,
                synopsis: "Detailed", contentType: type))
    }

    func chapterList(for series: Series) async throws -> [Chapter] {
        try record("chapters")
        return [
            Chapter(
                sourceID: id, seriesURL: series.url,
                url: series.url.appending(path: "1"), name: "Chapter 1")
        ]
    }

    func chapterContent(for chapter: Chapter) async throws -> ChapterContent {
        try record("content")
        return .text(html: "<p>Words.</p>")
    }

    private func makeSeries(_ slug: String) -> Series {
        Series(
            sourceID: id,
            url: URL(string: "https://example.test/series/\(slug)")!,
            title: slug,
            contentType: type)
    }
}

/// Holds popular requests until the test releases them, allowing completion
/// order to differ deterministically from start order.
private actor DelayedSource: Source {
    nonisolated let id: Int64 = 77
    nonisolated let name = "Delayed"
    nonisolated let lang = "en"
    nonisolated let baseURL = URL(string: "https://delayed.test")!
    nonisolated let type = ContentType.novel

    private var started = 0
    private var pending: [Int: CheckedContinuation<SeriesPage, Never>] = [:]
    private var startWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    nonisolated func supports(_ filter: Filter) -> Bool { false }

    func popular(page: Int) async throws -> SeriesPage {
        let ordinal = started
        started += 1
        let ready = startWaiters.filter { started >= $0.0 }
        startWaiters.removeAll { started >= $0.0 }
        for (_, waiter) in ready { waiter.resume() }
        return await withCheckedContinuation { pending[ordinal] = $0 }
    }

    func waitForStarts(_ count: Int) async {
        guard started < count else { return }
        await withCheckedContinuation { startWaiters.append((count, $0)) }
    }

    func complete(_ ordinal: Int, title: String) {
        let page = SeriesPage(
            entries: [
                Series(
                    sourceID: id,
                    url: baseURL.appending(path: "series/one"),
                    title: title,
                    contentType: type)
            ],
            hasMore: false)
        pending.removeValue(forKey: ordinal)?.resume(returning: page)
    }

    func latest(page: Int) async throws -> SeriesPage { .empty }
    func search(
        query: String, page: Int, filters: FilterList
    ) async throws -> SeriesPage { .empty }
    func seriesDetails(for series: Series) async throws -> Series { series }
    func chapterList(for series: Series) async throws -> [Chapter] { [] }
    func chapterContent(for chapter: Chapter) async throws -> ChapterContent {
        .text(html: "")
    }
}

private struct Boom: Error {}

@Suite("DefaultCatalogRepository")
struct CatalogRepositoryTests {
    private let seriesURL = URL(string: "https://example.test/series/one")!

    private func makeRepository(
        _ source: CountingSource
    ) -> (DefaultCatalogRepository, CountingSource) {
        (DefaultCatalogRepository(registry: SourceRegistry([source])), source)
    }

    @Test("A source is resolved through the registry and its results returned")
    func fetchesThroughTheRegistry() async throws {
        let (repository, source) = makeRepository(CountingSource())
        let page = try await repository.popular(sourceID: source.id, page: 1, refresh: false)

        #expect(page.entries.map(\.title) == ["popular-1"])
        #expect(source.callCount("popular") == 1)
    }

    /// The requirement: a repeat request within the lifetime is served from
    /// memory and issues no network request.
    @Test("An identical request within the lifetime does not reach the source")
    func repeatRequestIsServedFromCache() async throws {
        let (repository, source) = makeRepository(CountingSource())

        _ = try await repository.popular(sourceID: source.id, page: 1, refresh: false)
        _ = try await repository.popular(sourceID: source.id, page: 1, refresh: false)
        _ = try await repository.popular(sourceID: source.id, page: 1, refresh: false)

        #expect(source.callCount("popular") == 1)
    }

    @Test("A different page is a different request")
    func pagesAreCachedSeparately() async throws {
        let (repository, source) = makeRepository(CountingSource())

        _ = try await repository.popular(sourceID: source.id, page: 1, refresh: false)
        _ = try await repository.popular(sourceID: source.id, page: 2, refresh: false)

        #expect(source.callCount("popular") == 2)
    }

    @Test("Popular and latest do not share a cache entry")
    func operationsAreCachedSeparately() async throws {
        let (repository, source) = makeRepository(CountingSource())

        _ = try await repository.popular(sourceID: source.id, page: 1, refresh: false)
        _ = try await repository.latest(sourceID: source.id, page: 1, refresh: false)

        #expect(source.callCount("popular") == 1)
        #expect(source.callCount("latest") == 1)
    }

    /// Pull-to-refresh. Without this the reader has no way to see a new chapter
    /// until an invisible timer elapses.
    @Test("A refresh bypasses the cache")
    func refreshBypassesTheCache() async throws {
        let (repository, source) = makeRepository(CountingSource())

        _ = try await repository.popular(sourceID: source.id, page: 1, refresh: false)
        _ = try await repository.popular(sourceID: source.id, page: 1, refresh: true)

        #expect(source.callCount("popular") == 2)
    }

    /// A refresh that did not overwrite would be undone by the next read, which
    /// would serve the stale value the refresh was issued to replace.
    @Test("A refresh replaces the entry it bypassed")
    func refreshReplacesTheCachedEntry() async throws {
        let (repository, source) = makeRepository(CountingSource())

        _ = try await repository.popular(sourceID: source.id, page: 1, refresh: false)
        _ = try await repository.popular(sourceID: source.id, page: 1, refresh: true)
        _ = try await repository.popular(sourceID: source.id, page: 1, refresh: false)

        // Two: the original, and the refresh. The third read was served the
        // refreshed value rather than re-fetching or resurrecting the old one.
        #expect(source.callCount("popular") == 2)
    }

    @Test("A slower stale miss cannot overwrite a completed refresh")
    func staleCompletionCannotOverwriteRefresh() async throws {
        let source = DelayedSource()
        let repository = DefaultCatalogRepository(registry: SourceRegistry([source]))

        let stale = Task {
            try await repository.popular(sourceID: source.id, page: 1, refresh: false)
        }
        await source.waitForStarts(1)

        let refresh = Task {
            try await repository.popular(sourceID: source.id, page: 1, refresh: true)
        }
        await source.waitForStarts(2)

        await source.complete(1, title: "fresh")
        #expect(try await refresh.value.entries.first?.title == "fresh")
        await source.complete(0, title: "stale")
        #expect(try await stale.value.entries.first?.title == "stale")

        let cached = try await repository.popular(
            sourceID: source.id, page: 1, refresh: false)
        #expect(cached.entries.first?.title == "fresh")
    }

    @Test("Searches differing in case and spacing remain distinct requests")
    func searchKeysPreserveTheRequest() async throws {
        let (repository, source) = makeRepository(CountingSource())

        _ = try await repository.search(
            sourceID: source.id, query: "One Piece", page: 1, filters: .none, refresh: false)
        _ = try await repository.search(
            sourceID: source.id, query: "  one   piece ", page: 1, filters: .none, refresh: false)

        #expect(source.callCount("search") == 2)
    }

    @Test("Searches with different filters are different requests")
    func filtersDistinguishSearches() async throws {
        let (repository, source) = makeRepository(CountingSource())

        _ = try await repository.search(
            sourceID: source.id, query: "q", page: 1,
            filters: FilterList([.genre("Action")]), refresh: false)
        _ = try await repository.search(
            sourceID: source.id, query: "q", page: 1,
            filters: FilterList([.genre("Drama")]), refresh: false)

        #expect(source.callCount("search") == 2)
    }

    @Test("Details are cached and enrich the series passed in")
    func detailsAreCachedAndEnriched() async throws {
        let (repository, source) = makeRepository(CountingSource())
        let known = Series(
            sourceID: source.id, url: seriesURL, title: "Known",
            author: "From The Listing", contentType: .novel)

        let first = try await repository.details(for: known, refresh: false)
        _ = try await repository.details(for: known, refresh: false)

        #expect(source.callCount("details") == 1)
        #expect(first.synopsis == "Detailed")
        #expect(first.author == "From The Listing")
        #expect(first.id == known.id)
    }

    @Test("Detail caching does not discard richer catalog metadata")
    func detailCacheIncludesKnownMetadata() async throws {
        let (repository, source) = makeRepository(CountingSource())
        let sparse = Series(
            sourceID: source.id, url: seriesURL, title: "Known", contentType: .novel)
        let richer = Series(
            sourceID: source.id, url: seriesURL, title: "Known",
            author: "Later Catalog Author", contentType: .novel)

        _ = try await repository.details(for: sparse, refresh: false)
        let detailed = try await repository.details(for: richer, refresh: false)

        #expect(source.callCount("details") == 2)
        #expect(detailed.author == "Later Catalog Author")
    }

    @Test("Chapter lists are cached per series")
    func chapterListsAreCached() async throws {
        let (repository, source) = makeRepository(CountingSource())
        let series = Series(sourceID: source.id, url: seriesURL, title: "One", contentType: .novel)
        let other = Series(
            sourceID: source.id,
            url: URL(string: "https://example.test/series/two")!,
            title: "Two",
            contentType: .novel)

        _ = try await repository.chapters(for: series, refresh: false)
        _ = try await repository.chapters(for: series, refresh: false)
        _ = try await repository.chapters(for: other, refresh: false)

        #expect(source.callCount("chapters") == 2)
    }

    /// "This source is gone" and "this source has nothing" are different answers,
    /// and a reader cannot tell them apart from an empty screen.
    @Test("An unknown source throws rather than returning empty")
    func unknownSourceThrows() async {
        let (repository, _) = makeRepository(CountingSource())

        await #expect(throws: CatalogRepositoryError.unknownSource(999)) {
            try await repository.popular(sourceID: 999, page: 1, refresh: false)
        }
    }

    @Test("A failing source propagates rather than being swallowed")
    func failurePropagates() async {
        let (repository, source) = makeRepository(CountingSource())
        source.failNext(with: Boom())

        await #expect(throws: Boom.self) {
            try await repository.popular(sourceID: source.id, page: 1, refresh: false)
        }
    }

    /// Caching a failure turns one bad response into minutes of a catalog that
    /// refuses to load, with a retry button that cannot work.
    @Test("A failure is not cached")
    func failuresAreNotCached() async throws {
        let (repository, source) = makeRepository(CountingSource())
        source.failNext(with: Boom())

        _ = try? await repository.popular(sourceID: source.id, page: 1, refresh: false)
        let page = try await repository.popular(sourceID: source.id, page: 1, refresh: false)

        #expect(page.entries.isEmpty == false)
        #expect(source.callCount("popular") == 2)
    }

    @Test("Clearing the caches sends the next request back to the source")
    func clearingCachesRefetches() async throws {
        let (repository, source) = makeRepository(CountingSource())

        _ = try await repository.popular(sourceID: source.id, page: 1, refresh: false)
        await repository.clearCaches()
        _ = try await repository.popular(sourceID: source.id, page: 1, refresh: false)

        #expect(source.callCount("popular") == 2)
    }

    @Test("Sources are projected as domain metadata")
    func sourcesAreProjected() async {
        let (repository, source) = makeRepository(CountingSource())
        let infos = await repository.sources()

        #expect(infos.map(\.id) == [source.id])
        #expect(infos.first?.name == "Counting")
    }

    @Test("The live registry discovers both initial plugins as domain metadata")
    func liveSourcesAreProjected() async {
        let http = HTTPClient(session: StubURLProtocol.makeSession())
        let repository = DefaultCatalogRepository(
            registry: SourceRegistry(liveSources(http: http)))

        let infos = await repository.sources()

        #expect(infos.map(\.name) == ["AsuraScans", "FreeWebNovel"])
        #expect(infos.map(\.contentType) == [.manhwa, .novel])
    }

    @Test("Filter support is answered by the source, and an unknown source supports nothing")
    func filterSupportIsDelegated() async {
        let (repository, source) = makeRepository(CountingSource())

        #expect(await repository.supports(.genre("Action"), sourceID: source.id))
        #expect(await repository.supports(.sort("latest"), sourceID: source.id) == false)
        #expect(await repository.supports(.genre("Action"), sourceID: 999) == false)
    }
}
