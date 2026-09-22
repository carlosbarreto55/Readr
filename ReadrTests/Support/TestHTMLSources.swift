import Foundation
import SwiftSoup

@testable import Readr

// Test-only `HTMLSource` subclasses over hand-written markup.
//
// Deliberately not one of the real plugins: `HTMLSourceTests` tests the *base
// type*, and driving it through a real site's selectors would fail whenever that
// site changed, for reasons that have nothing to do with the code under test.
// Real fixtures belong to the plugin suites, in `ReadrTests/Fixtures/<sitename>/`.

/// A minimal novel source over hand-written markup.
///
/// Deliberately not one of the real plugins: this suite tests the *base
/// type*, and driving it through a real site's selectors would fail whenever
/// that site changed, for reasons that have nothing to do with `HTMLSource`.
final class TestNovelSource: HTMLSource, @unchecked Sendable {
    init(http: HTTPClient) {
        super.init(
            http: http,
            name: "TestNovels",
            lang: "en",
            baseURL: URL(string: "https://novels.test")!,
            type: .novel)
    }

    override func popularURL(page: Int) -> URL {
        URL(string: "https://novels.test/popular/\(page)")!
    }
    override var popularSelector: String { "div.card" }
    override var nextPageSelector: String? { "a.next" }

    override func searchURL(query: String, page: Int, filters: FilterList) -> URL {
        URL(string: "https://novels.test/search?q=\(query)&page=\(page)")!
    }

    override func series(from element: Element) throws -> Series {
        guard let link = try element.select("a.title").first(),
            let url = try link.absoluteURL(),
            let title = try link.trimmedText()
        else {
            throw SourceError.requiredFieldMissing(
                field: "title", source: name, url: baseURL)
        }
        return Series(
            sourceID: id,
            url: url,
            title: title,
            coverURL: try element.select("img").first()?.absoluteURL("src"),
            contentType: type)
    }

    override func parseDetails(_ document: Document, known: Series) throws -> Series {
        let title = try document.first("h1")?.trimmedText() ?? ""
        return Series(
            sourceID: id,
            url: known.url,
            title: title,
            synopsis: try document.first("div.synopsis")?.trimmedText(),
            author: try document.first("span.author")?.trimmedText(),
            genres: try document.select("a.genre").array().compactMap { try $0.trimmedText() },
            status: Self.status(try document.first("span.status")?.trimmedText()),
            contentType: type)
    }

    private static func status(_ text: String?) -> SeriesStatus {
        switch text?.lowercased() {
        case "ongoing": return .ongoing
        case "completed": return .completed
        // Anything the source does not recognize degrades rather than failing.
        default: return .unknown
        }
    }

    override var chapterSelector: String { "ul.chapters a" }

    override func chapter(from element: Element, series: Series) throws -> Chapter {
        guard let url = try element.absoluteURL() else {
            throw SourceError.requiredFieldMissing(
                field: "chapter url", source: name, url: series.url)
        }
        return Chapter(
            sourceID: id,
            seriesURL: series.url,
            url: url,
            name: try element.trimmedText() ?? "Untitled")
    }

    /// Records the thread parsing ran on, so the suite can assert it was not
    /// the main one. The failure mode is a dropped frame, not an error, so
    /// nothing else would catch a regression.
    nonisolated(unsafe) var parsedOnMainThread: Bool?

    override func parseText(_ document: Document) throws -> String {
        parsedOnMainThread = Thread.isMainThread
        guard let body = try document.first("div#content") else {
            throw SourceError.requiredFieldMissing(
                field: "content", source: name, url: baseURL)
        }
        return try body.html()
    }
}

final class TestManhwaSource: HTMLSource, @unchecked Sendable {
    init(http: HTTPClient) {
        super.init(
            http: http,
            name: "TestManhwa",
            lang: "en",
            baseURL: URL(string: "https://manhwa.test")!,
            type: .manhwa)
    }

    override func parsePages(_ document: Document) throws -> [URL] {
        try document.select("div#reader img").array().compactMap { try $0.absoluteURL("src") }
    }
}

/// Returns a malformed catalog value so the base type's required-title guard is
/// exercised independently of a well-behaved plugin extractor.
final class BlankListingSource: HTMLSource, @unchecked Sendable {
    init(http: HTTPClient) {
        super.init(
            http: http,
            name: "BlankListing",
            lang: "en",
            baseURL: URL(string: "https://blank.test")!,
            type: .novel)
    }

    override func popularURL(page: Int) -> URL {
        URL(string: "https://blank.test/popular/\(page)")!
    }

    override var popularSelector: String { "div.card" }
    override var nextPageSelector: String? { nil }

    override func series(from element: Element) throws -> Series {
        Series(
            sourceID: id,
            url: URL(string: "https://blank.test/series/one")!,
            title: "   ",
            contentType: type)
    }
}

/// Declares `.manhwa` and implements neither shape — the case
/// `source-contract` requires to throw rather than return an empty chapter.
final class ForgetfulSource: HTMLSource, @unchecked Sendable {
    init(http: HTTPClient) {
        super.init(
            http: http,
            name: "Forgetful",
            lang: "en",
            baseURL: URL(string: "https://forgot.test")!,
            type: .manhwa)
    }
}
