import Foundation
import Testing

@testable import Readr

@Suite("CatalogPager")
@MainActor
struct CatalogPagerTests {

    /// Records which pages were asked for, so a test can assert what was *not*
    /// requested — which is how "exactly one request in flight" and "the retry
    /// re-requests the same index" are proved.
    private final class PageSource: @unchecked Sendable {
        private let lock = NSLock()
        private var requested: [Int] = []
        private var pages: [Int: Result<SeriesPage, any Error>] = [:]
        private var delay: Duration = .zero

        init(delay: Duration = .zero) { self.delay = delay }

        func provide(page: Int, _ result: Result<SeriesPage, any Error>) {
            lock.withLock { pages[page] = result }
        }

        var requestedPages: [Int] { lock.withLock { requested } }

        func fetch(_ page: Int) async throws -> SeriesPage {
            let (result, wait) = lock.withLock {
                requested.append(page)
                return (pages[page], delay)
            }
            if wait > .zero { try await Task.sleep(for: wait) }
            switch result {
            case .success(let page): return page
            case .failure(let error): throw error
            case nil: return .empty
            }
        }
    }

    private struct Boom: Error, Equatable {}

    private func series(_ path: String, sourceID: Int64 = 1) -> Series {
        Series(
            sourceID: sourceID,
            url: URL(string: "https://example.test/\(path)")!,
            title: path,
            contentType: .novel)
    }

    @Test("An opened catalog requests page 1")
    func firstLoadRequestsPageOne() async {
        let source = PageSource()
        source.provide(page: 1, .success(SeriesPage(entries: [series("a")], hasMore: false)))
        let pager = CatalogPager(fetch: source.fetch)

        await pager.loadFirstPage()

        #expect(source.requestedPages == [1])
        #expect(pager.state.entries.map(\.title) == ["a"])
        #expect(pager.state.isLoading == false)
    }

    @Test("Page N+1 is appended after page N, in source order")
    func pagesAppendInOrder() async {
        let source = PageSource()
        source.provide(
            page: 1, .success(SeriesPage(entries: [series("a"), series("b")], hasMore: true)))
        source.provide(
            page: 2, .success(SeriesPage(entries: [series("c"), series("d")], hasMore: false)))
        let pager = CatalogPager(fetch: source.fetch)

        await pager.loadFirstPage()
        await pager.loadNextPage()

        #expect(source.requestedPages == [1, 2])
        #expect(pager.state.entries.map(\.title) == ["a", "b", "c", "d"])
    }

    /// Sites repeat entries across a page boundary routinely, because the
    /// underlying list shifts between the two requests. Appending the duplicate
    /// would show the reader the same card twice.
    @Test("An entry already loaded is discarded rather than appended")
    func duplicatesAreDiscarded() async {
        let source = PageSource()
        source.provide(
            page: 1, .success(SeriesPage(entries: [series("a"), series("b")], hasMore: true)))
        source.provide(
            page: 2, .success(SeriesPage(entries: [series("b"), series("c")], hasMore: false)))
        let pager = CatalogPager(fetch: source.fetch)

        await pager.loadFirstPage()
        await pager.loadNextPage()

        #expect(pager.state.entries.map(\.title) == ["a", "b", "c"])
    }

    /// Identity is `(sourceID, url)`. Two sources publishing the same URL are two
    /// different series and both belong in the list.
    @Test("Entries sharing a URL across sources are not treated as duplicates")
    func duplicateDetectionIncludesSourceID() async {
        let source = PageSource()
        source.provide(
            page: 1,
            .success(
                SeriesPage(
                    entries: [series("same", sourceID: 1), series("same", sourceID: 2)],
                    hasMore: false)))
        let pager = CatalogPager(fetch: source.fetch)

        await pager.loadFirstPage()

        #expect(pager.state.entries.count == 2)
    }

    /// A scroll handler fires far faster than a request completes. Without the
    /// guard, one flick of the thumb issues a dozen requests for the same page.
    @Test("A load-more during a pending request is ignored")
    func onlyOneRequestIsInFlight() async {
        let source = PageSource(delay: .milliseconds(50))
        source.provide(page: 1, .success(SeriesPage(entries: [series("a")], hasMore: true)))
        source.provide(page: 2, .success(SeriesPage(entries: [series("b")], hasMore: true)))
        let pager = CatalogPager(fetch: source.fetch)
        await pager.loadFirstPage()

        async let first: Void = pager.loadNextPage()
        async let second: Void = pager.loadNextPage()
        async let third: Void = pager.loadNextPage()
        _ = await (first, second, third)

        // Page 1 from the initial load, then page 2 exactly once.
        #expect(source.requestedPages == [1, 2])
    }

    @Test("hasMore == false stops further requests")
    func lastPageStopsPaging() async {
        let source = PageSource()
        source.provide(page: 1, .success(SeriesPage(entries: [series("a")], hasMore: false)))
        let pager = CatalogPager(fetch: source.fetch)

        await pager.loadFirstPage()
        await pager.loadNextPage()
        await pager.loadNextPage()

        #expect(source.requestedPages == [1])
        #expect(pager.state.hasMore == false)
    }

    /// A pager that kept the flag set after a failure would refuse every later
    /// request, so a catalog that failed once would look permanently stalled
    /// rather than broken.
    @Test("A failure clears the in-flight flag and surfaces the error")
    func failureClearsTheFlag() async {
        let source = PageSource()
        source.provide(page: 1, .failure(Boom()))
        let pager = CatalogPager(fetch: source.fetch)

        await pager.loadFirstPage()

        #expect(pager.state.isLoading == false)
        #expect(pager.state.failure is Boom)
    }

    /// The index was never advanced past the page that failed, so the retry
    /// re-requests it by construction rather than by remembering which one it was.
    @Test("A retry re-requests the same page index")
    func retryRepeatsTheFailedPage() async {
        let source = PageSource()
        source.provide(
            page: 1, .success(SeriesPage(entries: [series("a")], hasMore: true)))
        source.provide(page: 2, .failure(Boom()))
        let pager = CatalogPager(fetch: source.fetch)

        await pager.loadFirstPage()
        await pager.loadNextPage()
        #expect(source.requestedPages == [1, 2])

        source.provide(page: 2, .success(SeriesPage(entries: [series("b")], hasMore: false)))
        await pager.retry()

        #expect(source.requestedPages == [1, 2, 2])
        #expect(pager.state.entries.map(\.title) == ["a", "b"])
        #expect(pager.state.failure == nil)
    }

    @Test("A refresh discards what was loaded and starts at page 1")
    func refreshStartsOver() async {
        let source = PageSource()
        source.provide(page: 1, .success(SeriesPage(entries: [series("a")], hasMore: true)))
        source.provide(page: 2, .success(SeriesPage(entries: [series("b")], hasMore: false)))
        let pager = CatalogPager(fetch: source.fetch)

        await pager.loadFirstPage()
        await pager.loadNextPage()
        #expect(pager.state.entries.count == 2)

        source.provide(page: 1, .success(SeriesPage(entries: [series("c")], hasMore: false)))
        await pager.refresh()

        #expect(source.requestedPages == [1, 2, 1])
        #expect(pager.state.entries.map(\.title) == ["c"])
    }

    /// An empty catalog is not an error and must not be presented as one.
    @Test("An empty first page is empty, not a failure")
    func emptyIsNotAnError() async {
        let source = PageSource()
        source.provide(page: 1, .success(.empty))
        let pager = CatalogPager(fetch: source.fetch)

        await pager.loadFirstPage()

        #expect(pager.state.entries.isEmpty)
        #expect(pager.state.failure == nil)
        #expect(pager.state.isEmpty)
    }
}
