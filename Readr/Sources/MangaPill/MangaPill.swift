import Foundation
import SwiftSoup

/// English translations of Japanese manga on MangaPill's manga-only catalog.
final class MangaPill: HTMLSource, @unchecked Sendable {
    init(http: HTTPClient) {
        super.init(
            http: http, name: "MangaPill", lang: "en",
            baseURL: URL(string: "https://mangapill.com")!, type: .manga)
    }

    override func popularURL(page: Int) -> URL { listingURL(query: "", page: page) }
    override func latestURL(page: Int) -> URL { listingURL(query: "", page: page) }
    // The site has no typed latest-chapter route. Use one finite manga-only
    // catalog page rather than mixing in other content from its update feed.
    override var latestPageLimit: Int? { 1 }
    override var latestNextPageSelector: String? { nil }
    override var popularSelector: String {
        "div.grid.grid-cols-2 > div:has(a[href^='/manga/'] img[data-src])"
    }
    override var nextPageSelector: String? { "a.btn[href*='page=']:matchesOwn(Next)" }
    override var searchSelector: String { popularSelector }
    override var searchNextPageSelector: String? { nextPageSelector }

    override func searchURL(query: String, page: Int, filters: FilterList) -> URL {
        listingURL(query: query, page: page)
    }

    override func series(from element: Element) throws -> Series {
        let requestURL = URL(string: element.getBaseUri()) ?? baseURL
        guard let link = try element.select("a[href^='/manga/']:has(img[data-src])").first(),
            let url = try link.absoluteURL()
        else {
            throw SourceError.requiredFieldMissing(
                field: "series url", source: name, url: requestURL)
        }
        guard
            let title = try element.select("a[href^='/manga/'] div.font-black").first()?
                .trimmedText()
        else {
            throw SourceError.requiredFieldMissing(field: "title", source: name, url: url)
        }
        let coverURL = try link.select("img[data-src]").first()?.absoluteURL("data-src")
        let labels = try element.select("div.bg-green-500").array().compactMap {
            try $0.trimmedText()
        }
        return Series(
            sourceID: id, url: url, title: title, coverURL: coverURL,
            status: Self.status(from: labels.first), contentType: type)
    }

    override func parseDetails(_ document: Document, known: Series) throws -> Series {
        let synopsis = try document.select("p.text-sm").first()?.trimmedText()
        let status = try document.select("label:matchesOwn(Status) + div").first()?.trimmedText()
        let genres = try document.select("a[href^='/search?genre=']").array()
            .compactMap { try $0.trimmedText() }
        return Series(
            sourceID: id, url: known.url,
            title: try document.select("h1.font-bold").first()?.trimmedText() ?? "",
            coverURL: try document.select("img[data-src]").first()?.absoluteURL("data-src"),
            synopsis: synopsis, genres: genres, status: Self.status(from: status),
            contentType: type)
    }

    override var chapterSelector: String { "#chapters a[href^='/chapters/']" }

    override func chapter(from element: Element, series: Series) throws -> Chapter {
        guard let url = try element.absoluteURL() else {
            throw SourceError.requiredFieldMissing(
                field: "chapter url", source: name, url: series.url)
        }
        guard let chapterName = try element.trimmedText() else {
            throw SourceError.requiredFieldMissing(
                field: "chapter name", source: name, url: series.url)
        }
        let number = chapterName.range(of: "Chapter ", options: .caseInsensitive)
            .flatMap { Double(chapterName[$0.upperBound...].prefix { $0.isNumber || $0 == "." }) }
        return Chapter(
            sourceID: id, seriesURL: series.url, url: url,
            name: chapterName, number: number)
    }

    override func parsePages(_ document: Document) throws -> [URL] {
        let requestURL = URL(string: document.location()) ?? baseURL
        let images = try document.select("img.js-page[data-src]").array()
        guard !images.isEmpty else {
            throw SourceError.requiredFieldMissing(
                field: "chapter pages", source: name, url: requestURL)
        }
        return try images.map { image in
            guard let url = try image.absoluteURL("data-src") else {
                throw SourceError.requiredFieldMissing(
                    field: "chapter page url", source: name, url: requestURL)
            }
            return url
        }
    }

    private func listingURL(query: String, page: Int) -> URL {
        var components = URLComponents(
            url: baseURL.appending(path: "search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "manga")
        ]
        if page > 1 {
            components.queryItems?.append(URLQueryItem(name: "page", value: String(page)))
        }
        return components.url!
    }

    private static func status(from value: String?) -> SeriesStatus {
        switch value?.lowercased() {
        case "publishing": .ongoing
        case "finished": .completed
        case "on hiatus": .hiatus
        default: .unknown
        }
    }
}
