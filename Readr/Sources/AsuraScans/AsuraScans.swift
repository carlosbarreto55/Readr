import Foundation
import SwiftSoup

/// English manhwa from AsuraScans's server-rendered Astro pages.
final class AsuraScans: HTMLSource, @unchecked Sendable {
    init(http: HTTPClient) {
        super.init(
            http: http,
            name: "AsuraScans",
            lang: "en",
            baseURL: URL(string: "https://asurascans.com")!,
            type: .manhwa)
    }

    override var requestHeaders: [String: String] {
        [
            "User-Agent":
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                + "(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
            "Accept":
                "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9"
        ]
    }

    override func popularURL(page: Int) -> URL {
        let browse = baseURL.appending(path: "browse")
        guard page > 1 else { return browse }
        return Self.url(browse, queryItems: [URLQueryItem(name: "page", value: String(page))])
    }

    override var popularSelector: String { "#series-grid div.series-card" }

    override var nextPageSelector: String? {
        "a[aria-label=\"Next page\"]:not(.opacity-25)"
    }

    override func latestURL(page: Int) -> URL { baseURL }

    override var latestSelector: String {
        "div.grid.grid-cols-12.gap-2.py-4.px-2.border-b"
    }

    override var latestNextPageSelector: String? { nil }

    override var latestPageLimit: Int? { 1 }

    override func latestSeries(from element: Element) throws -> Series {
        let requestURL = Self.requestURL(for: element, fallback: baseURL)
        guard
            let titleLink = try element.select("a.font-bold.text-base.line-clamp-1").first()
                ?? element.select("a[href^=\"/comics/\"]").first(),
            let url = try titleLink.absoluteURL()
        else {
            throw SourceError.requiredFieldMissing(
                field: "series url", source: name, url: requestURL)
        }
        guard let title = try titleLink.trimmedText() else {
            throw SourceError.requiredFieldMissing(
                field: "title", source: name, url: url)
        }

        let cover =
            try element.select("a.col-span-4 img").first()
            ?? element.select("img").first()
        return Series(
            sourceID: id,
            url: url,
            title: title,
            coverURL: try cover?.absoluteURL("src"),
            contentType: type)
    }

    override func searchURL(query: String, page: Int, filters: FilterList) -> URL {
        var items = [URLQueryItem(name: "search", value: query)]
        if page > 1 {
            items.append(URLQueryItem(name: "page", value: String(page)))
        }
        return Self.url(baseURL.appending(path: "browse"), queryItems: items)
    }

    override func series(from element: Element) throws -> Series {
        let requestURL = Self.requestURL(for: element, fallback: baseURL)
        guard
            let coverLink = try element.select("a[href^=\"/comics/\"]").first(),
            let url = try coverLink.absoluteURL()
        else {
            throw SourceError.requiredFieldMissing(
                field: "series url", source: name, url: requestURL)
        }
        guard let title = try element.select("h3").first()?.trimmedText() else {
            throw SourceError.requiredFieldMissing(
                field: "title", source: name, url: url)
        }

        return Series(
            sourceID: id,
            url: url,
            title: title,
            coverURL: try coverLink.select("img").first()?.absoluteURL("src"),
            status: Self.status(
                from: try element.select("span.capitalize").first()?.trimmedText()),
            contentType: type)
    }

    override func parseDetails(_ document: Document, known: Series) throws -> Series {
        let status =
            try document.select("span.capitalize").array()
            .compactMap { try $0.trimmedText() }
            .map(Self.status(from:))
            .first { $0 != .unknown } ?? .unknown
        let genres = try document.select("a[href^=\"/browse?genres=\"]").array()
            .compactMap { try $0.trimmedText() }
        let synopsis = try document.first("meta[name=description]")?.attr("content")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Series(
            sourceID: id,
            url: known.url,
            title: try document.first("article h1")?.trimmedText() ?? "",
            coverURL: try document.first("#desktop-cover-container img")?.absoluteURL("src"),
            synopsis: synopsis,
            author: try document.first("a[href^=\"/browse?author=\"]")?.trimmedText(),
            artist: try document.first("a[href^=\"/browse?artist=\"]")?.trimmedText(),
            genres: genres,
            status: status,
            contentType: type)
    }

    override var chapterSelector: String {
        "a[data-astro-prefetch=\"hover\"][href*=\"/chapter/\"]"
    }

    override func chapter(from element: Element, series: Series) throws -> Chapter {
        guard let url = try element.absoluteURL() else {
            throw SourceError.requiredFieldMissing(
                field: "chapter url", source: name, url: series.url)
        }
        guard
            let chapterName = try element.select("span.font-medium").first()?.trimmedText()
                ?? element.trimmedText()
        else {
            throw SourceError.requiredFieldMissing(
                field: "chapter name", source: name, url: series.url)
        }
        let rawDate = try element.select(
            "span.text-sm[class*=\"text-white/40\"]"
        ).first()?.trimmedText()

        return Chapter(
            sourceID: id,
            seriesURL: series.url,
            url: url,
            name: chapterName,
            number: Self.chapterNumber(from: chapterName),
            dateUploaded: rawDate.flatMap(Self.date(from:)))
    }

    override func parsePages(_ document: Document) throws -> [URL] {
        let elements = try document.select("div[data-page] img").array()
        let requestURL = URL(string: document.location()) ?? baseURL
        guard !elements.isEmpty else {
            throw SourceError.requiredFieldMissing(
                field: "chapter pages",
                source: name,
                url: requestURL)
        }
        return try elements.map { element in
            guard let url = try element.absoluteURL("src") else {
                throw SourceError.requiredFieldMissing(
                    field: "chapter page url", source: name, url: requestURL)
            }
            return url
        }
    }

    private static func status(from text: String?) -> SeriesStatus {
        switch text?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "ongoing": .ongoing
        case "completed": .completed
        case "hiatus": .hiatus
        case "cancelled": .cancelled
        default: .unknown
        }
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

    private static func date(from raw: String) -> Date? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM d, yyyy"
        if let absolute = formatter.date(from: value) {
            return absolute
        }

        if value.caseInsensitiveCompare("last week") == .orderedSame {
            return Calendar.current.date(byAdding: .day, value: -7, to: .now)
        }

        let components = value.lowercased().split(separator: " ")
        guard components.count == 3, components[2] == "ago",
            let amount = Int(components[0])
        else {
            return nil
        }
        let component: Calendar.Component
        switch components[1].trimmingCharacters(in: CharacterSet(charactersIn: "s")) {
        case "hour": component = .hour
        case "day": component = .day
        case "week": component = .weekOfYear
        case "month": component = .month
        case "year": component = .year
        default: return nil
        }
        return Calendar.current.date(byAdding: component, value: -amount, to: .now)
    }

    private static func url(_ base: URL, queryItems: [URLQueryItem]) -> URL {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems
        return components.url!
    }

    private static func requestURL(for element: Element, fallback: URL) -> URL {
        URL(string: element.getBaseUri()) ?? fallback
    }
}
