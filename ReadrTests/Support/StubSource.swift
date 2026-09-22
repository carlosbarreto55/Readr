import Foundation

@testable import Readr

/// A `Source` that contacts nothing.
///
/// This is a test double for exercising the contract surface — registry lookup,
/// identity, content-shape agreement. It is not a site plugin and parses no
/// markup. Real plugins are fixture-driven.
struct StubSource: Source {
    let id: Int64
    let name: String
    let lang: String
    let baseURL: URL
    let type: ContentType

    /// What every catalog call returns.
    var page: SeriesPage = .empty
    /// Filters this source claims to support.
    var supportedFilters: Set<String> = []

    init(
        name: String,
        lang: String = "en",
        type: ContentType = .novel,
        baseURL: URL = URL(string: "https://example.test")!,
        page: SeriesPage = .empty,
        supportedFilters: Set<String> = []
    ) {
        self.id = computeSourceID(name: name, lang: lang, type: type)
        self.name = name
        self.lang = lang
        self.type = type
        self.baseURL = baseURL
        self.page = page
        self.supportedFilters = supportedFilters
    }

    func supports(_ filter: Filter) -> Bool {
        switch filter {
        case .genre: supportedFilters.contains("genre")
        case .status: supportedFilters.contains("status")
        case .sort: supportedFilters.contains("sort")
        }
    }

    func popular(page _: Int) async throws -> SeriesPage { page }
    func latest(page _: Int) async throws -> SeriesPage { page }
    func search(query _: String, page _: Int, filters _: FilterList) async throws -> SeriesPage {
        page
    }

    func seriesDetails(for series: Series) async throws -> Series { series }
    func chapterList(for _: Series) async throws -> [Chapter] { [] }

    /// Returns the shape this source's `type` promises, never both.
    func chapterContent(for _: Chapter) async throws -> ChapterContent {
        switch type {
        case .novel: .text(html: "<p>Stub chapter.</p>")
        case .manhwa: .pages(imageURLs: [URL(string: "https://example.test/p/1.jpg")!])
        }
    }
}
