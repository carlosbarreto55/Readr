import Foundation
import Testing

@testable import Readr

@Suite("MangaPill", .serialized)
struct MangaPillTests {
    private func source() -> MangaPill {
        MangaPill(http: HTTPClient(session: StubURLProtocol.makeSession()))
    }

    @Test("Persisted source identity is stable")
    func identity() {
        #expect(source().name == "MangaPill")
        #expect(source().lang == "en")
        #expect(source().type == .manga)
        #expect(source().id == 6_311_723_684_592_463_265)
    }

    @Test("Manga-only catalog parses observed cards and next page")
    func catalog() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://mangapill.com/search?q=&type=manga")!
        registry.stub(url, html: try loadFixture("mangapill/search.html"))
        let page = try await source().popular(page: 1)
        #expect(page.entries.first?.title == "Berserk")
        #expect(page.entries.first?.contentType == .manga)
        #expect(page.entries.first?.coverURL?.host() == "cdn.readdetectiveconan.com")
        #expect(page.hasMore)
        #expect(registry.requestedURLs == [url])
    }

    @Test("Search encodes query and advances pagination")
    func search() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://mangapill.com/search?q=one%20piece&type=manga&page=2")!
        registry.stub(url, html: try loadFixture("mangapill/search.html"))
        let page = try await source().search(query: "one piece", page: 2, filters: .none)
        #expect(page.entries.count > 0)
        #expect(registry.requestedURLs == [url])
    }

    @Test("Finite manga catalog stops latest at page one")
    func latest() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://mangapill.com/search?q=&type=manga")!
        registry.stub(url, html: try loadFixture("mangapill/search.html"))
        #expect(try await source().latest(page: 1).hasMore == false)
        #expect(try await source().latest(page: 2) == .empty)
        #expect(registry.requestedURLs == [url])
    }

    @Test("Series details and chapter links follow observed markup")
    func detailsAndChapters() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://mangapill.com/manga/1/berserk")!
        registry.stub(url, html: try loadFixture("mangapill/series.html"))
        let known = Series(sourceID: source().id, url: url, title: "Known", contentType: .manga)
        let details = try await source().seriesDetails(for: known)
        #expect(details.title == "Berserk")
        #expect(details.status == .ongoing)
        #expect(details.genres.contains("Action"))
        #expect(details.synopsis?.contains("Black Swordsman") == true)
        let chapters = try await source().chapterList(for: known)
        #expect(chapters.first?.name == "Group 2 Chapter 386")
        #expect(chapters.first?.number == 386)
        #expect(chapters.first?.url.path() == "/chapters/1-20386000/berserk-chapter-386")
    }

    @Test("Chapter pages use lazy URLs in source order")
    func pages() async throws {
        let registry = StubURLProtocol.install()
        let seriesURL = URL(string: "https://mangapill.com/manga/1/berserk")!
        let url = URL(string: "https://mangapill.com/chapters/1-20386000/berserk-chapter-386")!
        registry.stub(url, html: try loadFixture("mangapill/chapter.html"))
        let chapter = Chapter(
            sourceID: source().id, seriesURL: seriesURL, url: url, name: "Chapter 386")
        guard case .pages(let urls) = try await source().chapterContent(for: chapter) else {
            Issue.record("Expected pages")
            return
        }
        #expect(urls.count == 24)
        #expect(urls.first?.lastPathComponent == "1.jpeg")
        #expect(urls.last?.lastPathComponent == "24.jpeg")
    }

    @Test("Missing page markup throws with chapter context")
    func missingPages() async {
        let registry = StubURLProtocol.install()
        let seriesURL = URL(string: "https://mangapill.com/manga/1/berserk")!
        let url = URL(string: "https://mangapill.com/chapters/broken")!
        registry.stub(url, html: "<html></html>")
        let chapter = Chapter(sourceID: source().id, seriesURL: seriesURL, url: url, name: "Broken")
        await #expect(
            throws: SourceError.requiredFieldMissing(
                field: "chapter pages", source: "MangaPill", url: url)
        ) {
            try await source().chapterContent(for: chapter)
        }
    }
}
