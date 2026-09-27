import Foundation
import SwiftSoup

/// English western comics — Marvel, DC, and Image — from ReadComicsOnline.
///
/// A Next.js site. Listings and series pages are server-rendered markup, but an
/// issue page renders only its first page as an `<img>`; the full ordered page
/// list travels in the React Server Components payload embedded in the HTML.
final class ReadComicsOnline: HTMLSource, @unchecked Sendable {
    init(http: HTTPClient) {
        super.init(
            http: http, name: "ReadComicsOnline", lang: "en",
            baseURL: URL(string: "https://readcomicsonline.lol")!, type: .comic)
    }

    // The full catalog, the week's releases, and search results are each served
    // as one page; the site ignores `?page=`, so no listing has a next page.
    override func popularURL(page: Int) -> URL { baseURL.appending(path: "comics") }
    override var popularSelector: String { "a[href^='/comic/']:has(h3):has(img)" }
    override var nextPageSelector: String? { nil }

    override func latestURL(page: Int) -> URL { baseURL.appending(path: "new-comics") }
    override var latestPageLimit: Int? { 1 }
    override var latestSelector: String { "div.flex.gap-4:has(h2 a[href^='/comic/'])" }

    override func searchURL(query: String, page: Int, filters: FilterList) -> URL {
        var components = URLComponents(
            url: baseURL.appending(path: "search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return components.url!
    }

    override func series(from element: Element) throws -> Series {
        let requestURL = URL(string: element.getBaseUri()) ?? baseURL
        guard let url = try element.absoluteURL() else {
            throw SourceError.requiredFieldMissing(
                field: "series url", source: name, url: requestURL)
        }
        guard let title = try element.select("h3").first()?.trimmedText() else {
            throw SourceError.requiredFieldMissing(field: "title", source: name, url: url)
        }
        return Series(
            sourceID: id, url: url, title: title,
            coverURL: try element.select("img[src]").first()?.absoluteURL("src"),
            status: Self.status(from: try element.select("div.uppercase").first()?.trimmedText()),
            contentType: type)
    }

    override func latestSeries(from element: Element) throws -> Series {
        let requestURL = URL(string: element.getBaseUri()) ?? baseURL
        guard let link = try element.select("h2 a[href^='/comic/']").first(),
            let url = try link.absoluteURL()
        else {
            throw SourceError.requiredFieldMissing(
                field: "series url", source: name, url: requestURL)
        }
        guard let title = try link.trimmedText() else {
            throw SourceError.requiredFieldMissing(field: "title", source: name, url: url)
        }
        return Series(
            sourceID: id, url: url, title: title,
            coverURL: try element.select("img[src]").first()?.absoluteURL("src"),
            contentType: type)
    }

    override func parseDetails(_ document: Document, known: Series) throws -> Series {
        // The breadcrumb names the publisher; it leads the genres so Marvel and DC
        // titles are told apart at a glance. Desktop and mobile layouts each render
        // the genre tags, hence the de-duplication.
        let publisher = try document.select("nav[aria-label=Breadcrumb] a[href^='/publisher/']")
            .first()?.trimmedText()
        var genres: [String] = []
        for tag in [publisher].compactMap({ $0 })
            + (try document.select("a.inline-flex[href^='/genre/']").array()
                .compactMap { try $0.trimmedText() })
        where !genres.contains(tag) {
            genres.append(tag)
        }
        return Series(
            sourceID: id, url: known.url,
            title: try document.select("h1").first()?.trimmedText() ?? "",
            coverURL: try document.select("img[data-nimg=1][src*='/covers/']").first()?
                .absoluteURL("src"),
            synopsis: try document.select("h2:matchesOwn(^Summary$) + p").first()?.trimmedText(),
            author: try document.select("span:matchesOwn(^Writer$) + span").first()?.trimmedText(),
            genres: genres,
            contentType: type)
    }

    override var chapterSelector: String { "a[href^='/comic/']:has(span.truncate)" }

    override func chapter(from element: Element, series: Series) throws -> Chapter {
        guard let url = try element.absoluteURL() else {
            throw SourceError.requiredFieldMissing(
                field: "chapter url", source: name, url: series.url)
        }
        guard let chapterName = try element.select("span.truncate").first()?.trimmedText() else {
            throw SourceError.requiredFieldMissing(
                field: "chapter name", source: name, url: series.url)
        }
        // Issues live at `/comic/<series>/<issue>`: `24`, `1.1` for a variant
        // edition, or a slug such as `Absolute-Batman-Annual-1`, which has no number.
        let uploaded = try element.select("span.whitespace-nowrap").first()?.trimmedText()
        return Chapter(
            sourceID: id, seriesURL: series.url, url: url, name: chapterName,
            number: Double(url.lastPathComponent),
            dateUploaded: uploaded.flatMap { try? Self.uploadDate.parse($0) })
    }

    override func parsePages(_ document: Document) throws -> [URL] {
        let requestURL = URL(string: document.location()) ?? baseURL
        guard
            let script = try document.select("script").array()
                .first(where: { $0.data().contains(Self.escapedPagesMarker) })
        else {
            throw SourceError.requiredFieldMissing(
                field: "chapter pages", source: name, url: requestURL)
        }
        let pages = try Self.pageEntries(
            inFlightScript: script.data(), source: name, url: requestURL)
        guard !pages.isEmpty else {
            throw SourceError.requiredFieldMissing(
                field: "chapter pages", source: name, url: requestURL)
        }
        return pages.sorted { $0.pageNumber < $1.pageNumber }.map(\.url)
    }

    // MARK: - Page payload

    private struct PageEntry: Decodable {
        let pageNumber: Int
        let url: URL
    }

    /// `"pages":[` as it appears inside the payload's JavaScript string literal.
    private static let escapedPagesMarker = #"\"pages\":["#

    /// The page list inside one `self.__next_f.push([1,"…"])` script.
    ///
    /// The pushed chunk is a JSON string literal; decoding it yields the flight
    /// text, whose `"pages":[…]` array is plain JSON once its bounds are found.
    private static func pageEntries(
        inFlightScript script: String, source: String, url: URL
    ) throws -> [PageEntry] {
        guard let open = script.range(of: "[1,\"")?.upperBound,
            let close = script.range(of: "\"]", options: .backwards)?.lowerBound,
            open <= close,
            let text = try JSONSerialization.jsonObject(
                with: Data("\"\(script[open..<close])\"".utf8), options: .fragmentsAllowed)
                as? String,
            let start = text.range(of: "\"pages\":[")?.upperBound,
            let array = balancedArray(in: text, after: start)
        else {
            throw SourceError.requiredFieldMissing(
                field: "chapter pages", source: source, url: url)
        }
        return try JSONDecoder().decode([PageEntry].self, from: Data(array.utf8))
    }

    /// The JSON array whose `[` ends just before `index`, brackets inside strings
    /// ignored — or `nil` when the text ends before the array closes.
    private static func balancedArray(in text: String, after index: String.Index) -> Substring? {
        let begin = text.index(before: index)
        var depth = 0
        var inString = false
        var escaped = false
        var position = begin
        while position < text.endIndex {
            let character = text[position]
            if inString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else if character == "\"" {
                inString = true
            } else if character == "[" {
                depth += 1
            } else if character == "]" {
                depth -= 1
                if depth == 0 { return text[begin...position] }
            }
            position = text.index(after: position)
        }
        return nil
    }

    private static let uploadDate = Date.ISO8601FormatStyle().year().month().day()

    private static func status(from value: String?) -> SeriesStatus {
        switch value?.lowercased() {
        case "ongoing": .ongoing
        case "completed": .completed
        default: .unknown
        }
    }
}
