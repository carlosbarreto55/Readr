import Foundation
import Testing

@testable import Readr

@Suite("ReadComicsOnline", .serialized)
struct ReadComicsOnlineTests {
    private let seriesURL = URL(string: "https://readcomicsonline.lol/comic/Absolute-Batman")!

    private func source() -> ReadComicsOnline {
        ReadComicsOnline(http: HTTPClient(session: StubURLProtocol.makeSession()))
    }

    @Test("Persisted source identity is stable")
    func identity() {
        #expect(source().name == "ReadComicsOnline")
        #expect(source().lang == "en")
        #expect(source().type == .comic)
        #expect(source().id == -8_130_615_070_770_881_488)
    }

    @Test("The full catalog is one page of series cards")
    func catalog() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://readcomicsonline.lol/comics")!
        registry.stub(url, html: try loadFixture("readcomicsonline/comics.html"))
        let page = try await source().popular(page: 1)
        #expect(page.entries.count == 207)
        #expect(Set(page.entries.map(\.url)).count == 207)
        let first = try #require(page.entries.first)
        #expect(first.title == "Absolute Batman")
        #expect(first.url == seriesURL)
        #expect(first.status == .ongoing)
        #expect(first.contentType == .comic)
        #expect(
            first.coverURL?.absoluteString
                == "https://cdn.readcomicsonline.lol/covers-sm/Absolute-Batman/1.webp")
        #expect(page.entries.allSatisfy { $0.url.pathComponents.count == 3 })
        #expect(!page.hasMore)
        #expect(registry.requestedURLs == [url])
    }

    @Test("New releases list each series once and stop at page one")
    func latest() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://readcomicsonline.lol/new-comics")!
        registry.stub(url, html: try loadFixture("readcomicsonline/new-comics.html"))
        let page = try await source().latest(page: 1)
        #expect(page.entries.count == 20)
        #expect(Set(page.entries.map(\.url)).count == 20)
        #expect(page.entries.first?.title == "Wolverine (2024)")
        #expect(page.entries.first?.url.path() == "/comic/Wolverine-2024")
        #expect(page.entries.first?.coverURL?.host() == "cdn.readcomicsonline.lol")
        #expect(!page.hasMore)
        #expect(try await source().latest(page: 2) == .empty)
        #expect(registry.requestedURLs == [url])
    }

    @Test("Search encodes the query and returns one page")
    func search() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://readcomicsonline.lol/search?q=Batman")!
        registry.stub(url, html: try loadFixture("readcomicsonline/search-batman.html"))
        let page = try await source().search(query: "Batman", page: 1, filters: .none)
        #expect(page.entries.count == 16)
        #expect(page.entries.map(\.title).contains("Batman (2025)"))
        #expect(!page.hasMore)
        #expect(registry.requestedURLs == [url])
    }

    @Test("Series details come from the observed header, summary, and breadcrumb")
    func details() async throws {
        let registry = StubURLProtocol.install()
        registry.stub(
            seriesURL, html: try loadFixture("readcomicsonline/series-absolute-batman.html"))
        let known = Series(
            sourceID: source().id, url: seriesURL, title: "Known", status: .ongoing,
            contentType: .comic)
        let details = try await source().seriesDetails(for: known)
        #expect(details.title == "Absolute Batman")
        #expect(details.author == "Scott Snyder")
        #expect(details.genres == ["DC Comics", "Action", "Superhero"])
        #expect(details.synopsis?.hasPrefix("BATMAN LEGEND SCOTT SNYDER") == true)
        #expect(
            details.coverURL?.absoluteString
                == "https://cdn.readcomicsonline.lol/covers/Absolute-Batman/1.webp")
        // The series page states no status; the one known from the listing survives.
        #expect(details.status == .ongoing)
    }

    @Test("Issues are listed newest first with numbers and upload dates")
    func chapters() async throws {
        let registry = StubURLProtocol.install()
        registry.stub(
            seriesURL, html: try loadFixture("readcomicsonline/series-absolute-batman.html"))
        let known = Series(sourceID: source().id, url: seriesURL, title: "", contentType: .comic)
        let chapters = try await source().chapterList(for: known)
        #expect(chapters.count == 26)
        let newest = try #require(chapters.first)
        #expect(newest.name == "Absolute Batman #24")
        #expect(newest.number == 24)
        #expect(newest.url.path() == "/comic/Absolute-Batman/24")
        #expect(newest.dateUploaded == Date(timeIntervalSince1970: 1_790_035_200))
        let annual = try #require(chapters.first { $0.name == "Absolute Batman Annual 1" })
        #expect(annual.number == nil)
        #expect(chapters.first { $0.url.lastPathComponent == "1.1" }?.number == 1.1)
        #expect(chapters.last?.number == 1)
    }

    @Test("Issue pages come from the embedded page list in page-number order")
    func pages() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://readcomicsonline.lol/comic/Absolute-Batman/24")!
        registry.stub(url, html: try loadFixture("readcomicsonline/issue-absolute-batman-24.html"))
        let chapter = Chapter(
            sourceID: source().id, seriesURL: seriesURL, url: url, name: "Absolute Batman #24")
        guard case .pages(let urls) = try await source().chapterContent(for: chapter) else {
            Issue.record("Expected pages")
            return
        }
        #expect(urls.count == 28)
        #expect(
            urls.first?.absoluteString
                == "https://cdn.readcomicsonline.lol/pages/Absolute-Batman/24/p001.webp")
        #expect(urls.last?.lastPathComponent == "p028.webp")
        #expect(urls.map(\.lastPathComponent) == urls.map(\.lastPathComponent).sorted())
    }

    @Test("An issue without a page list throws with issue context")
    func missingPages() async {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://readcomicsonline.lol/comic/Absolute-Batman/broken")!
        registry.stub(
            url,
            html: #"<html><body><img src="https://cdn.readcomicsonline.lol/pages/x/p001.webp">"#
                + #"<script>self.__next_f.push([1,"0:[\"$\",\"div\",null,{}]"])</script>"#
                + "</body></html>")
        let chapter = Chapter(sourceID: source().id, seriesURL: seriesURL, url: url, name: "Broken")
        await #expect(
            throws: SourceError.requiredFieldMissing(
                field: "chapter pages", source: "ReadComicsOnline", url: url)
        ) {
            try await source().chapterContent(for: chapter)
        }
    }
}
