import Foundation
import Testing

@testable import Readr

@Suite("FreeWebNovel", .serialized)
struct FreeWebNovelTests {
    private func source() -> FreeWebNovel {
        FreeWebNovel(http: HTTPClient(session: StubURLProtocol.makeSession()))
    }

    @Test("Identity inputs and the persisted ID are frozen")
    func identityIsStable() {
        _ = StubURLProtocol.install()
        let source = source()

        #expect(source.name == "FreeWebNovel")
        #expect(source.lang == "en")
        #expect(source.type == .novel)
        #expect(source.id == -4_449_706_879_672_731_846)
    }

    @Test("Popular parses cards and is a single-page catalog")
    func popularParses() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://freewebnovel.com/sort/most-popular")!
        registry.stub(url, html: try loadFixture("freewebnovel/popular.html"))

        let page = try await source().popular(page: 1)

        #expect(page.entries.map(\.title) == ["Invincible", "Advent of the Three Calamities"])
        #expect(
            page.entries.first?.url.absoluteString
                == "https://freewebnovel.com/novel/invincible-novel")
        #expect(page.entries.first?.coverURL?.host() == "freewebnovel.com")
        #expect(page.entries.first?.status == .completed)
        #expect(page.entries.last?.status == .unknown)
        #expect(page.hasMore == false)
    }

    @Test("Latest pages use distinct URLs and recognize a next link")
    func latestPaginates() async throws {
        let registry = StubURLProtocol.install()
        let page1URL = URL(string: "https://freewebnovel.com/sort/latest-release")!
        let page2URL = URL(string: "https://freewebnovel.com/sort/latest-release/2")!
        let fixture = try loadFixture("freewebnovel/latest.html")
        registry.stub(page1URL, html: fixture)
        registry.stub(
            page2URL,
            html: fixture.replacingOccurrences(
                of: "<a href=\"/sort/latest-release/2\">&gt;&gt;</a>",
                with: "<a href=\"javascript:void(0);\">&gt;&gt;</a>"))

        let source = source()
        let first = try await source.latest(page: 1)
        let second = try await source.latest(page: 2)

        #expect(first.entries.first?.title == "Supreme Mars")
        #expect(first.hasMore)
        #expect(second.hasMore == false)
        #expect(registry.requestedURLs == [page1URL, page2URL])
    }

    @Test("Search form-encodes its query and parses results")
    func searchParses() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://freewebnovel.com/search?searchkey=shadow+slave")!
        registry.stub(url, html: try loadFixture("freewebnovel/search.html"))

        let page = try await source().search(
            query: "shadow slave", page: 1, filters: .none)

        #expect(page.entries.map(\.title) == ["Shadow Slave"])
        #expect(page.hasMore == false)
        #expect(registry.requestedURLs == [url])
    }

    @Test("Details enrich all observed novel metadata")
    func detailsParse() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(
            string: "https://freewebnovel.com/novel/advent-of-the-three-calamities")!
        registry.stub(url, html: try loadFixture("freewebnovel/series.html"))
        let known = Series(
            sourceID: source().id,
            url: url,
            title: "Listing Title",
            contentType: .novel)

        let series = try await source().seriesDetails(for: known)

        #expect(series.title == "Advent of the Three Calamities")
        #expect(series.author == "Entrail_JI")
        #expect(series.synopsis?.contains("Emotions are like a drug") == true)
        #expect(series.genres == ["Fantasy", "Romance", "Action"])
        #expect(series.status == .ongoing)
        #expect(series.coverURL?.absoluteString.contains("/files/article/image/") == true)
        #expect(series.id == known.id)
    }

    @Test("Chapter names, decimal numbers, and URLs preserve source order")
    func chaptersParse() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(
            string: "https://freewebnovel.com/novel/advent-of-the-three-calamities")!
        registry.stub(url, html: try loadFixture("freewebnovel/series.html"))
        let series = Series(
            sourceID: source().id, url: url,
            title: "Advent of the Three Calamities", contentType: .novel)

        let chapters = try await source().chapterList(for: series)

        #expect(chapters.map(\.name) == ["Chapter 1: Prologue [1]", "Chapter 2233.2: An Interlude"])
        #expect(chapters.map(\.number) == [1, 2233.2])
        #expect(chapters.map(\.seriesURL) == [url, url])
        #expect(chapters.last?.url.absoluteString.hasSuffix("/chapter-2233.2") == true)
    }

    @Test("Novel content excludes ads, scripts, and watermarks")
    func chapterTextIsCleaned() async throws {
        let registry = StubURLProtocol.install()
        let seriesURL = URL(
            string: "https://freewebnovel.com/novel/advent-of-the-three-calamities")!
        let chapterURL = seriesURL.appending(path: "chapter-876")
        registry.stub(chapterURL, html: try loadFixture("freewebnovel/chapter.html"))
        let chapter = Chapter(
            sourceID: source().id, seriesURL: seriesURL, url: chapterURL,
            name: "Chapter 876")

        guard case .text(let html) = try await source().chapterContent(for: chapter) else {
            Issue.record("Expected novel text")
            return
        }

        #expect(html.contains("Julien opened his eyes"))
        #expect(html.contains("The room was silent"))
        #expect(html.contains("Advertisement") == false)
        #expect(html.contains("window.ad") == false)
        #expect(html.contains("watermark") == false)
    }

    @Test("Malformed required card and chapter content throw")
    func requiredMarkupThrows() async {
        let registry = StubURLProtocol.install()
        let catalogURL = URL(string: "https://freewebnovel.com/sort/most-popular")!
        registry.stub(
            catalogURL,
            html: "<div class=\"ul-list1 ul-list1-2 ss-custom\"><div class=\"li-row\"></div></div>")

        await #expect(
            throws: SourceError.requiredFieldMissing(
                field: "series url", source: "FreeWebNovel", url: catalogURL)
        ) {
            try await source().popular(page: 1)
        }

        let seriesURL = URL(string: "https://freewebnovel.com/novel/broken")!
        let chapterURL = seriesURL.appending(path: "chapter-1")
        registry.stub(chapterURL, html: "<html><body></body></html>")
        let chapter = Chapter(
            sourceID: source().id, seriesURL: seriesURL, url: chapterURL,
            name: "Chapter 1")
        await #expect(
            throws: SourceError.requiredFieldMissing(
                field: "chapter content", source: "FreeWebNovel", url: chapterURL)
        ) {
            try await source().chapterContent(for: chapter)
        }
    }
}
