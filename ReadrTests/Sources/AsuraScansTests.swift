import Foundation
import Testing

@testable import Readr

@Suite("AsuraScans", .serialized)
struct AsuraScansTests {
    private func source() -> AsuraScans {
        AsuraScans(http: HTTPClient(session: StubURLProtocol.makeSession()))
    }

    @Test("Identity inputs and the persisted ID are frozen")
    func identityIsStable() {
        _ = StubURLProtocol.install()
        let source = source()

        #expect(source.name == "AsuraScans")
        #expect(source.lang == "en")
        #expect(source.type == .manhwa)
        #expect(source.id == 1_352_820_880_324_575_906)
    }

    @Test("Browse parses cards, pagination, statuses, and browser headers")
    func popularParses() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://asurascans.com/browse")!
        registry.stub(url, html: try loadFixture("asurascans/popular.html"))

        let page = try await source().popular(page: 1)

        #expect(
            page.entries.map(\.title) == ["Eternally Regressing Knight", "Solo Max-Level Newbie"])
        #expect(page.entries.map(\.status) == [.ongoing, .completed])
        #expect(page.entries.first?.coverURL?.host() == "cdn.asurascans.com")
        #expect(page.hasMore)
        let headers = try #require(registry.headers.first)
        #expect(Self.header("User-Agent", in: headers)?.contains("Chrome/125") == true)
        #expect(Self.header("Accept-Language", in: headers) == "en-US,en;q=0.9")
    }

    @Test("Browse page two has a distinct URL")
    func popularPaginates() async throws {
        let registry = StubURLProtocol.install()
        let page2URL = URL(string: "https://asurascans.com/browse?page=2")!
        registry.stub(page2URL, html: try loadFixture("asurascans/popular.html"))

        _ = try await source().popular(page: 2)

        #expect(registry.requestedURLs == [page2URL])
    }

    @Test("Homepage latest uses its distinct layout and is one page")
    func latestParses() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://asurascans.com")!
        registry.stub(url, html: try loadFixture("asurascans/latest.html"))

        let page = try await source().latest(page: 1)

        #expect(
            page.entries.map(\.title) == ["Eternally Regressing Knight", "Solo Max-Level Newbie"])
        #expect(page.entries.allSatisfy { $0.url.path().hasPrefix("/comics/") })
        #expect(page.hasMore == false)
    }

    @Test("Homepage latest stops after page one without another request")
    func latestStopsAfterFirstPage() async throws {
        let registry = StubURLProtocol.install()

        let page = try await source().latest(page: 2)

        #expect(page == .empty)
        #expect(registry.requestedURLs.isEmpty)
    }

    @Test("Search percent-encodes a query and page")
    func searchParses() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://asurascans.com/browse?search=solo%20play&page=2")!
        registry.stub(url, html: try loadFixture("asurascans/search.html"))

        let page = try await source().search(
            query: "solo play", page: 2, filters: .none)

        #expect(page.entries.map(\.title) == ["Emperor of Solo Play"])
        #expect(page.entries.first?.status == .hiatus)
        #expect(registry.requestedURLs == [url])
    }

    @Test("Details enrich every observed manhwa field")
    func detailsParse() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(
            string: "https://asurascans.com/comics/eternally-regressing-knight-b6e039fe")!
        registry.stub(url, html: try loadFixture("asurascans/series_detail.html"))
        let known = Series(
            sourceID: source().id, url: url,
            title: "Listing Title", contentType: .manhwa)

        let series = try await source().seriesDetails(for: known)

        #expect(series.title == "Eternally Regressing Knight")
        #expect(series.author == "Kanara")
        #expect(series.artist == "JQ Comics")
        #expect(series.synopsis?.contains("without genius") == true)
        #expect(series.genres == ["Action", "Fantasy"])
        #expect(series.status == .ongoing)
        #expect(series.coverURL?.host() == "cdn.asurascans.com")
        #expect(series.id == known.id)
    }

    @Test("Chapters preserve order and parse relative and absolute dates")
    func chaptersParse() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(
            string: "https://asurascans.com/comics/eternally-regressing-knight-b6e039fe")!
        registry.stub(url, html: try loadFixture("asurascans/series_detail.html"))
        let series = Series(
            sourceID: source().id, url: url,
            title: "Eternally Regressing Knight", contentType: .manhwa)

        let chapters = try await source().chapterList(for: series)

        #expect(chapters.map(\.name) == ["Chapter 108", "Chapter 107", "Chapter 106"])
        #expect(chapters.map(\.number) == [108, 107, 106])
        #expect(chapters.allSatisfy { $0.dateUploaded != nil })
        let absolute = try #require(chapters.last?.dateUploaded)
        let components = Calendar(identifier: .gregorian).dateComponents(
            in: TimeZone(secondsFromGMT: 0)!, from: absolute)
        #expect(components.year == 2026)
        #expect(components.month == 4)
        #expect(components.day == 4)
    }

    @Test("Manhwa pages are absolute and remain in document order")
    func chapterPagesParse() async throws {
        let registry = StubURLProtocol.install()
        let seriesURL = URL(
            string: "https://asurascans.com/comics/eternally-regressing-knight-b6e039fe")!
        let chapterURL = seriesURL.appending(path: "chapter/108")
        registry.stub(chapterURL, html: try loadFixture("asurascans/chapter.html"))
        let chapter = Chapter(
            sourceID: source().id, seriesURL: seriesURL, url: chapterURL,
            name: "Chapter 108")

        guard case .pages(let urls) = try await source().chapterContent(for: chapter) else {
            Issue.record("Expected manhwa pages")
            return
        }

        #expect(urls.map(\.lastPathComponent) == ["c4aabc.webp", "77bb11.webp", "a509c9.webp"])
        #expect(urls.allSatisfy { $0.scheme == "https" })
    }

    @Test("Malformed required card and page content throw")
    func requiredMarkupThrows() async {
        let registry = StubURLProtocol.install()
        let catalogURL = URL(string: "https://asurascans.com/browse")!
        registry.stub(
            catalogURL,
            html: "<div id=\"series-grid\"><div class=\"series-card\"></div></div>")

        await #expect(
            throws: SourceError.requiredFieldMissing(
                field: "series url", source: "AsuraScans", url: catalogURL)
        ) {
            try await source().popular(page: 1)
        }

        let seriesURL = URL(string: "https://asurascans.com/comics/broken")!
        let chapterURL = seriesURL.appending(path: "chapter/1")
        registry.stub(chapterURL, html: "<html><body></body></html>")
        let chapter = Chapter(
            sourceID: source().id, seriesURL: seriesURL, url: chapterURL,
            name: "Chapter 1")
        await #expect(
            throws: SourceError.requiredFieldMissing(
                field: "chapter pages", source: "AsuraScans", url: chapterURL)
        ) {
            try await source().chapterContent(for: chapter)
        }

        let brokenPageURL = seriesURL.appending(path: "chapter/2")
        registry.stub(brokenPageURL, html: "<div data-page=\"1\"><img></div>")
        let brokenPage = Chapter(
            sourceID: source().id, seriesURL: seriesURL, url: brokenPageURL,
            name: "Chapter 2")
        await #expect(
            throws: SourceError.requiredFieldMissing(
                field: "chapter page url", source: "AsuraScans", url: brokenPageURL)
        ) {
            try await source().chapterContent(for: brokenPage)
        }
    }

    private static func header(_ name: String, in headers: [String: String]) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}
