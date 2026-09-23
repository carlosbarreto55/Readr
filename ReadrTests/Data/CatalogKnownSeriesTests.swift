import Foundation
import Testing

@testable import Readr

/// A source whose every listing page holds one series named for the page.
private struct PagedSource: Source {
    let id: Int64 = 9
    let name = "Paged"
    let lang = "en"
    let baseURL = URL(string: "https://example.test")!
    let type = ContentType.novel

    func supports(_ filter: Filter) -> Bool { false }
    func popular(page: Int) async throws -> SeriesPage { listing("popular-\(page)") }
    func latest(page: Int) async throws -> SeriesPage { listing("latest-\(page)") }
    func search(query: String, page: Int, filters: FilterList) async throws -> SeriesPage {
        listing("search-\(query)")
    }
    func seriesDetails(for series: Series) async throws -> Series { series }
    func chapterList(for series: Series) async throws -> [Chapter] { [] }
    func chapterContent(for chapter: Chapter) async throws -> ChapterContent {
        .text(html: "")
    }

    func seriesID(_ slug: String) -> SeriesID {
        SeriesID(sourceID: id, url: baseURL.appending(path: "series/\(slug)"))
    }

    private func listing(_ slug: String) -> SeriesPage {
        SeriesPage(
            entries: [
                Series(
                    sourceID: id, url: baseURL.appending(path: "series/\(slug)"), title: slug,
                    contentType: type)
            ],
            hasMore: false)
    }
}

@Suite("DefaultCatalogRepository known series")
struct CatalogKnownSeriesTests {

    @Test("Listed series are remembered for a detail screen, including from a cache hit")
    func remembersListings() async throws {
        let source = PagedSource()
        let repository = DefaultCatalogRepository(registry: SourceRegistry([source]))

        _ = try await repository.popular(sourceID: source.id, page: 1, refresh: false)
        #expect(await repository.knownSeries(source.seriesID("popular-1"))?.title == "popular-1")
        #expect(await repository.knownSeries(source.seriesID("never-listed")) == nil)

        _ = try await repository.search(
            sourceID: source.id, query: "q", page: 1, filters: .none, refresh: false)
        _ = try await repository.search(
            sourceID: source.id, query: "q", page: 1, filters: .none, refresh: false)
        #expect(await repository.knownSeries(source.seriesID("search-q"))?.title == "search-q")
    }

    @Test("Remembered listings are bounded, oldest evicted first")
    func isBounded() async throws {
        let source = PagedSource()
        let repository = DefaultCatalogRepository(
            registry: SourceRegistry([source]), knownLimit: 2)

        for page in 1...3 {
            _ = try await repository.popular(sourceID: source.id, page: page, refresh: false)
        }

        #expect(await repository.knownSeries(source.seriesID("popular-1")) == nil)
        #expect(await repository.knownSeries(source.seriesID("popular-2")) != nil)
        #expect(await repository.knownSeries(source.seriesID("popular-3")) != nil)
    }
}
