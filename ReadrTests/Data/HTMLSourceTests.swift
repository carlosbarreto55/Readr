import Foundation
import SwiftSoup
import Testing

@testable import Readr

/// Tests the base type, not any site. The subclasses it drives live in
/// `Support/TestHTMLSources.swift`.
@Suite("HTMLSource", .serialized)
struct HTMLSourceTests {

    // MARK: - Fixtures

    private let listing = """
        <html><body>
          <div class="card">
            <a class="title" href="/series/one">First Series</a>
            <img src="/covers/one.jpg">
          </div>
          <div class="card">
            <a class="title" href="/series/two">Second Series</a>
          </div>
          <a class="next" href="/popular/2">Next</a>
        </body></html>
        """

    private let lastPage = """
        <html><body>
          <div class="card"><a class="title" href="/series/three">Third</a></div>
        </body></html>
        """

    private func client() -> HTTPClient {
        HTTPClient(session: StubURLProtocol.makeSession())
    }

    // MARK: - Identity

    /// A plugin states three inputs and gets the identifier `computeSourceID`
    /// produces. There is no override point for `id`, so "never hand-pick a
    /// source ID" is structural rather than a rule somebody has to remember.
    @Test("A source's id is derived from its name, lang, and type")
    func identityIsDerived() {
        _ = StubURLProtocol.install()
        let source = TestNovelSource(http: client())
        #expect(source.id == computeSourceID(name: "TestNovels", lang: "en", type: .novel))
    }

    @Test("The base advertises no filters a plugin did not opt into")
    func filtersDefaultToUnsupported() {
        _ = StubURLProtocol.install()
        let source = TestNovelSource(http: client())
        #expect(source.supports(.genre("Fantasy")) == false)
        #expect(source.supports(.status(.ongoing)) == false)
        #expect(source.supports(.sort("latest")) == false)
    }

    // MARK: - Listings

    @Test("A listing page parses into entries")
    func listingParses() async throws {
        let registry = StubURLProtocol.install()
        registry.stub(URL(string: "https://novels.test/popular/1")!, html: listing)

        let page = try await TestNovelSource(http: client()).popular(page: 1)

        #expect(page.entries.map(\.title) == ["First Series", "Second Series"])
        #expect(page.entries.first?.url == URL(string: "https://novels.test/series/one")!)
        #expect(page.entries.first?.coverURL == URL(string: "https://novels.test/covers/one.jpg")!)
    }

    @Test("hasMore follows the next-page selector")
    func hasMoreFollowsTheSelector() async throws {
        let registry = StubURLProtocol.install()
        registry.stub(URL(string: "https://novels.test/popular/1")!, html: listing)
        registry.stub(URL(string: "https://novels.test/popular/2")!, html: lastPage)

        let source = TestNovelSource(http: client())
        #expect(try await source.popular(page: 1).hasMore)
        #expect(try await source.popular(page: 2).hasMore == false)
    }

    /// `source-contract` is explicit: a reachable page that parses but holds
    /// nothing is empty, not an error.
    @Test("A page that parses but matches nothing is empty, not an error")
    func emptyPageIsNotAnError() async throws {
        let registry = StubURLProtocol.install()
        registry.stub(
            URL(string: "https://novels.test/popular/1")!,
            html: "<html><body><p>No results.</p></body></html>")

        let page = try await TestNovelSource(http: client()).popular(page: 1)

        #expect(page.entries.isEmpty)
        #expect(page.hasMore == false)
    }

    @Test("A plugin cannot return a blank-titled catalog entry")
    func blankListingTitleThrows() async {
        let registry = StubURLProtocol.install()
        registry.stub(
            URL(string: "https://blank.test/popular/1")!,
            html: "<html><body><div class=\"card\"></div></body></html>")
        let seriesURL = URL(string: "https://blank.test/series/one")!

        await #expect(
            throws: SourceError.requiredFieldMissing(
                field: "title", source: "BlankListing", url: seriesURL)
        ) {
            try await BlankListingSource(http: client()).popular(page: 1)
        }
    }

    @Test("Search reuses the listing path by default")
    func searchUsesTheSharedListingPath() async throws {
        let registry = StubURLProtocol.install()
        registry.stub(
            URL(string: "https://novels.test/search?q=first&page=1")!, html: listing)

        let page = try await TestNovelSource(http: client())
            .search(query: "first", page: 1, filters: .none)

        #expect(page.entries.count == 2)
    }

    // MARK: - Details

    /// The rule the base type exists to enforce. The plugin returns only what the
    /// page said; the merge that keeps the rest is not its job and so cannot be
    /// its omission.
    @Test("Details enrich the known series rather than replacing it")
    func detailsEnrich() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://novels.test/series/one")!
        registry.stub(
            url,
            html: """
                <html><body>
                  <h1>First Series</h1>
                  <div class="synopsis">A synopsis.</div>
                  <span class="status">Ongoing</span>
                </body></html>
                """)

        let known = Series(
            sourceID: 1,
            url: url,
            title: "First Series",
            coverURL: URL(string: "https://novels.test/covers/one.jpg")!,
            author: "Known From The Listing",
            genres: ["Fantasy"],
            contentType: .novel)

        let detailed = try await TestNovelSource(http: client()).seriesDetails(for: known)

        #expect(detailed.synopsis == "A synopsis.")
        #expect(detailed.status == .ongoing)
        // The detail page mentions neither, and neither is discarded.
        #expect(detailed.coverURL == known.coverURL)
        #expect(detailed.author == "Known From The Listing")
        #expect(detailed.genres == ["Fantasy"])
        #expect(detailed.id == known.id)
    }

    @Test("An unrecognized status degrades to unknown and the fetch succeeds")
    func unrecognizedStatusDegrades() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://novels.test/series/one")!
        registry.stub(
            url,
            html: """
                <html><body>
                  <h1>First Series</h1>
                  <span class="status">Indefinitely Postponed</span>
                </body></html>
                """)

        let known = Series(sourceID: 1, url: url, title: "First Series", contentType: .novel)
        let detailed = try await TestNovelSource(http: client()).seriesDetails(for: known)

        #expect(detailed.status == .unknown)
        #expect(detailed.title == "First Series")
    }

    @Test("Absent genres degrade to an empty list and the fetch succeeds")
    func absentGenresDegrade() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://novels.test/series/one")!
        registry.stub(url, html: "<html><body><h1>First Series</h1></body></html>")

        let known = Series(sourceID: 1, url: url, title: "Listing Title", contentType: .novel)
        let detailed = try await TestNovelSource(http: client()).seriesDetails(for: known)

        #expect(detailed.genres.isEmpty)
    }

    /// A blank title is the defect `library-blank-title-repair` exists to repair.
    /// Throwing here is how it stops being created.
    @Test("A title that cannot be parsed throws rather than returning a blank series")
    func missingTitleThrows() async {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://novels.test/series/one")!
        registry.stub(url, html: "<html><body><p>An error page.</p></body></html>")

        let known = Series(sourceID: 1, url: url, title: "Listing Title", contentType: .novel)
        await #expect(throws: SourceError.self) {
            try await TestNovelSource(http: client()).seriesDetails(for: known)
        }
    }

    // MARK: - Chapters

    @Test("A chapter list parses in source order")
    func chapterListParses() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://novels.test/series/one")!
        registry.stub(
            url,
            html: """
                <html><body><ul class="chapters">
                  <li><a href="/series/one/1">Chapter 1</a></li>
                  <li><a href="/series/one/2">Chapter 2</a></li>
                </ul></body></html>
                """)

        let series = Series(sourceID: 1, url: url, title: "One", contentType: .novel)
        let chapters = try await TestNovelSource(http: client()).chapterList(for: series)

        #expect(chapters.map(\.name) == ["Chapter 1", "Chapter 2"])
        #expect(chapters.first?.seriesURL == url)
    }

    @Test("A missing chapter-list anchor throws rather than returning an empty list")
    func missingChapterListThrows() async {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://novels.test/series/one")!
        registry.stub(url, html: "<html><body><p>An error page.</p></body></html>")

        let series = Series(sourceID: 1, url: url, title: "One", contentType: .novel)
        await #expect(
            throws: SourceError.requiredFieldMissing(
                field: "chapter list", source: "TestNovels", url: url)
        ) {
            try await TestNovelSource(http: client()).chapterList(for: series)
        }
    }
}

@Suite("HTMLSource chapter content", .serialized)
struct HTMLSourceContentTests {
    private func client() -> HTTPClient {
        HTTPClient(session: StubURLProtocol.makeSession())
    }

    // MARK: - Content shape

    @Test("A novel source returns text")
    func novelReturnsText() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://novels.test/series/one/1")!
        registry.stub(
            url, html: "<html><body><div id=\"content\"><p>Words.</p></div></body></html>")

        let chapter = Chapter(
            sourceID: 1,
            seriesURL: URL(string: "https://novels.test/series/one")!,
            url: url,
            name: "Chapter 1")

        guard
            case .text(let html) = try await TestNovelSource(http: client())
                .chapterContent(for: chapter)
        else {
            Issue.record("Expected .text")
            return
        }
        #expect(html.contains("Words."))
    }

    @Test("A manhwa source returns pages in reading order")
    func manhwaReturnsPages() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://manhwa.test/series/one/1")!
        registry.stub(
            url,
            html: """
                <html><body><div id="reader">
                  <img src="/p/1.jpg"><img src="/p/2.jpg"><img src="/p/3.jpg">
                </div></body></html>
                """)

        let chapter = Chapter(
            sourceID: 1,
            seriesURL: URL(string: "https://manhwa.test/series/one")!,
            url: url,
            name: "Chapter 1")

        guard
            case .pages(let urls) = try await TestManhwaSource(http: client())
                .chapterContent(for: chapter)
        else {
            Issue.record("Expected .pages")
            return
        }
        #expect(urls.map(\.lastPathComponent) == ["1.jpg", "2.jpg", "3.jpg"])
    }

    /// The alternative — a default returning empty text or no pages — renders a
    /// blank chapter that looks like the site broke rather than like the plugin
    /// is unfinished.
    @Test("A plugin implementing neither content shape throws")
    func missingContentShapeThrows() async {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://forgot.test/series/one/1")!
        registry.stub(url, html: "<html><body></body></html>")

        let chapter = Chapter(
            sourceID: 1,
            seriesURL: URL(string: "https://forgot.test/series/one")!,
            url: url,
            name: "Chapter 1")

        await #expect(
            throws: SourceError.contentShapeNotImplemented(
                source: "Forgetful", type: .manhwa, url: url)
        ) {
            try await ForgetfulSource(http: client()).chapterContent(for: chapter)
        }
    }

    // MARK: - Main actor

    /// `source-request-performance` requires parsing off the main actor. Nothing
    /// fails if it regresses — the UI just stutters — so this is the only thing
    /// that would catch it.
    @Test("Parsing does not run on the main actor")
    @MainActor
    func parsingIsOffTheMainActor() async throws {
        let registry = StubURLProtocol.install()
        let url = URL(string: "https://novels.test/series/one/1")!
        // Large enough that a main-actor parse would be a visible stall.
        let paragraphs = String(repeating: "<p>Words and more words.</p>", count: 2000)
        registry.stub(
            url, html: "<html><body><div id=\"content\">\(paragraphs)</div></body></html>")

        let source = TestNovelSource(http: client())
        let chapter = Chapter(
            sourceID: 1,
            seriesURL: URL(string: "https://novels.test/series/one")!,
            url: url,
            name: "Chapter 1")

        MainActor.assertIsolated("The test itself must start on the main actor")
        _ = try await source.chapterContent(for: chapter)

        #expect(source.parsedOnMainThread == false)
    }
}
