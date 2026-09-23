import Foundation
import SwiftSoup

/// English webnovels from FreeWebNovel's server-rendered HTML.
final class FreeWebNovel: HTMLSource, @unchecked Sendable {
    init(http: HTTPClient) {
        super.init(
            http: http,
            name: "FreeWebNovel",
            lang: "en",
            baseURL: URL(string: "https://freewebnovel.com")!,
            type: .novel)
    }

    override func popularURL(page: Int) -> URL {
        baseURL.appending(path: "sort/most-popular")
    }

    override var popularSelector: String {
        "div.ul-list1.ul-list1-2.ss-custom > div.li-row"
    }

    override var nextPageSelector: String? { nil }

    override func latestURL(page: Int) -> URL {
        var url = baseURL.appending(path: "sort/latest-release")
        if page > 1 {
            url.append(path: String(page))
        }
        return url
    }

    override var latestNextPageSelector: String? {
        "div.pages a:matches(>>):not([href*=\"javascript\"])"
    }

    override func searchURL(query: String, page: Int, filters: FilterList) -> URL {
        var components = URLComponents(
            url: baseURL.appending(path: "search"), resolvingAgainstBaseURL: false)!
        components.percentEncodedQuery = "searchkey=\(Self.formEncoded(query))"
        return components.url!
    }

    override func series(from element: Element) throws -> Series {
        let requestURL = Self.requestURL(for: element, fallback: baseURL)
        guard
            let titleLink = try element.select("h3.tit a[href^=\"/novel/\"]").first(),
            let url = try titleLink.absoluteURL()
        else {
            throw SourceError.requiredFieldMissing(
                field: "series url", source: name, url: requestURL)
        }

        return Series(
            sourceID: id,
            url: url,
            title: try titleLink.trimmedText() ?? "",
            coverURL: try element.select(".pic a img").first()?.absoluteURL("src"),
            status: try element.select("span.s2").first()?.trimmedText() == "Full"
                ? .completed : .unknown,
            contentType: type)
    }

    override func parseDetails(_ document: Document, known: Series) throws -> Series {
        let synopsis = try document.first(".m-desc .txt .inner")?.html()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let genres = try document.select(".m-book1 .txt .item a[href^=\"/genre/\"]").array()
            .compactMap { try $0.trimmedText() }
        let statusText = try document.first(
            ".m-book1 .txt .item:has(.glyphicon-time) .right .s1 a")?.trimmedText()

        return Series(
            sourceID: id,
            url: known.url,
            title: try document.first(".m-desc h1.tit")?.trimmedText() ?? "",
            coverURL: try document.first(".m-book1 .pic img")?.absoluteURL("src"),
            synopsis: synopsis,
            author: try document.first("a[href^=\"/author/\"]")?.trimmedText(),
            genres: genres,
            status: Self.status(from: statusText),
            contentType: type)
    }

    override var chapterSelector: String {
        "ul#idData a.con[href*=\"/chapter-\"]"
    }

    override func chapter(from element: Element, series: Series) throws -> Chapter {
        guard let url = try element.absoluteURL() else {
            throw SourceError.requiredFieldMissing(
                field: "chapter url", source: name, url: series.url)
        }
        guard let chapterName = try element.trimmedText() else {
            throw SourceError.requiredFieldMissing(
                field: "chapter name", source: name, url: series.url)
        }

        return Chapter(
            sourceID: id,
            seriesURL: series.url,
            url: url,
            name: chapterName,
            number: Self.chapterNumber(from: chapterName))
    }

    override func parseText(_ document: Document) throws -> String {
        let requestURL = URL(string: document.location()) ?? baseURL
        guard let article = try document.first("div#article") else {
            throw SourceError.requiredFieldMissing(
                field: "chapter content", source: name, url: requestURL)
        }

        _ = try article.select(
            "div[id^=\"pf-\"], div[id^=\"bg-ssp-\"], script, subtxt"
        ).remove()
        let html = try article.html().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !html.isEmpty else {
            throw SourceError.requiredFieldMissing(
                field: "chapter content", source: name, url: requestURL)
        }
        return html
    }

    private static func status(from text: String?) -> SeriesStatus {
        let normalized = text?.lowercased() ?? ""
        if normalized.contains("completed") { return .completed }
        if normalized.contains("ongoing") { return .ongoing }
        return .unknown
    }

    private static func chapterNumber(from name: String) -> Double? {
        guard let chapterRange = name.range(of: "chapter", options: .caseInsensitive) else {
            return nil
        }
        let remainder = name[chapterRange.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let number = remainder.prefix { $0.isNumber || $0 == "." }
        return Double(number)
    }

    private static func formEncoded(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._*")
        return value.addingPercentEncoding(withAllowedCharacters: allowed)?
            .replacingOccurrences(of: "%20", with: "+") ?? ""
    }

    private static func requestURL(for element: Element, fallback: URL) -> URL {
        URL(string: element.getBaseUri()) ?? fallback
    }
}
