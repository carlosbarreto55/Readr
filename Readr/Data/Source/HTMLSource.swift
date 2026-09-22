import Foundation
import SwiftSoup

/// The base type for sites served as HTML.
///
/// A convenience, not the architectural contract — `architecture.md` §5. `Source`
/// is the contract, and a site that is not HTML (a JSON API, say) implements it
/// directly rather than bending this type.
///
/// What a plugin supplies: URLs, CSS selectors, and the extraction of a domain
/// value from a matched element. What it never supplies: fetching, the timeout,
/// the concurrency bound, the detail merge, or the decision about which content
/// shape to return. Those are applied here so that a plugin cannot opt out of
/// them, and cannot get them subtly wrong one site at a time.
///
/// **Keep this type site-agnostic.** A behavior that names a site belongs in that
/// site's plugin — see `Readr/Sources/AGENTS.md` and the `source-contract`
/// requirement that governs it.
///
/// `@unchecked Sendable` because a non-final class cannot be checked: the
/// compiler cannot see what a subclass adds. The assurance is the rule that
/// plugins hold configuration in `let`s and no mutable state — a plugin that
/// caches into a `var` breaks it, and the `reviewer` lane is what catches that.
class HTMLSource: Source, @unchecked Sendable {

    let http: HTTPClient
    let name: String
    let lang: String
    let baseURL: URL
    let type: ContentType

    /// Derived, never supplied.
    ///
    /// `id` is a stored `let` computed in `init` rather than something a subclass
    /// can override, which is what makes "never hand-pick a source ID" structural
    /// instead of a rule in a document. A plugin cannot state an `id`; it states
    /// the three inputs and gets the one `computeSourceID` produces.
    let id: Int64

    init(http: HTTPClient, name: String, lang: String, baseURL: URL, type: ContentType) {
        self.http = http
        self.name = name
        self.lang = lang
        self.baseURL = baseURL
        self.type = type
        self.id = computeSourceID(name: name, lang: lang, type: type)
    }

    // MARK: - Fetching

    /// Headers sent with every request this source makes.
    ///
    /// Override to add what a site requires — some refuse a request without a
    /// browser-shaped `User-Agent` or `Accept`. Overriding this is the supported
    /// way to do that; overriding the fetch itself is not, because it would take
    /// the timeout and the concurrency bound with it.
    var requestHeaders: [String: String] { [:] }

    /// The body at `url`, as text.
    final func fetchText(_ url: URL) async throws -> String {
        try await http.text(from: url, source: name, headers: requestHeaders)
    }

    /// The document at `url`.
    ///
    /// Parsing runs here, inside a non-isolated `async` method, so it executes on
    /// the cooperative pool rather than the main actor —
    /// `source-request-performance` requires that, and a chapter of a few hundred
    /// kilobytes is enough to drop frames if it is ever violated.
    final func fetchDocument(_ url: URL) async throws -> Document {
        let html = try await fetchText(url)
        return try parse(html, baseURI: url)
    }

    /// Parses `html` with `url` as its base, so `abs:` attributes resolve.
    final func parse(_ html: String, baseURI url: URL) throws -> Document {
        try SwiftSoup.parse(html, url.absoluteString)
    }

    // MARK: - Catalog: what a plugin must supply

    /// The URL of the popular listing at `page` (1-based).
    func popularURL(page: Int) -> URL { Self.abstract("popularURL(page:)") }

    /// Matches one series card on a listing page.
    var popularSelector: String { Self.abstract("popularSelector") }

    /// Extracts a series from one matched card.
    func series(from element: Element) throws -> Series { Self.abstract("series(from:)") }

    /// Matches the next-page link, or `nil` where the listing is not paginated.
    ///
    /// Returning `nil` means `hasMore` is always `false`, which is correct for a
    /// single-page listing and wrong for a paginated one — a source whose paging
    /// silently stops at page 1 is the failure `source-listing-pagination` calls
    /// a stall.
    var nextPageSelector: String? { Self.abstract("nextPageSelector") }

    /// The URL of a search-results page.
    func searchURL(query: String, page: Int, filters: FilterList) -> URL {
        Self.abstract("searchURL(query:page:filters:)")
    }

    // MARK: - Catalog: what a plugin may supply

    /// The URL of the latest-updates listing at `page`.
    ///
    /// Defaults to the popular listing, because a site that does not distinguish
    /// them should not have to say so twice.
    func latestURL(page: Int) -> URL { popularURL(page: page) }

    /// Defaults to `popularSelector` — most sites reuse one card layout.
    var latestSelector: String { popularSelector }
    var latestNextPageSelector: String? { nextPageSelector }

    /// Extracts a series from a latest-listing row. Sites whose latest layout
    /// differs from their popular layout override this narrow hook.
    func latestSeries(from element: Element) throws -> Series { try series(from: element) }

    var searchSelector: String { popularSelector }
    var searchNextPageSelector: String? { nextPageSelector }

    func searchSeries(from element: Element) throws -> Series { try series(from: element) }

    // MARK: - Detail and chapters: what a plugin must supply

    /// What the detail page says, as a `Series`.
    ///
    /// The value returned here is folded onto the series already known — this
    /// type performs that merge, not the plugin. So a field this cannot parse is
    /// left `nil`, `""`, or `[]`, and the previously known value survives.
    ///
    /// - Throws: `SourceError.requiredFieldMissing` if the title cannot be parsed.
    ///   A blank title is the defect `library-blank-title-repair` exists to
    ///   repair, and throwing is how it stops being created.
    func parseDetails(_ document: Document, known: Series) throws -> Series {
        Self.abstract("parseDetails(_:known:)")
    }

    /// Matches one chapter row on the series page.
    var chapterSelector: String { Self.abstract("chapterSelector") }

    /// Extracts a chapter from one matched row.
    func chapter(from element: Element, series: Series) throws -> Chapter {
        Self.abstract("chapter(from:series:)")
    }

    // MARK: - Chapter content: exactly one of these

    /// The chapter body as HTML. **Novel sources override this.**
    func parseText(_ document: Document) throws -> String {
        throw SourceError.contentShapeNotImplemented(
            source: name,
            type: type,
            url: URL(string: document.location()) ?? baseURL)
    }

    /// The page image URLs in reading order. **Manhwa sources override this.**
    func parsePages(_ document: Document) throws -> [URL] {
        throw SourceError.contentShapeNotImplemented(
            source: name,
            type: type,
            url: URL(string: document.location()) ?? baseURL)
    }

    // MARK: - Source

    func supports(_ filter: Filter) -> Bool { false }

    final func popular(page: Int) async throws -> SeriesPage {
        try await listing(
            url: popularURL(page: page),
            selector: popularSelector,
            nextPageSelector: nextPageSelector,
            extract: series(from:)
        )
    }

    final func latest(page: Int) async throws -> SeriesPage {
        try await listing(
            url: latestURL(page: page),
            selector: latestSelector,
            nextPageSelector: latestNextPageSelector,
            extract: latestSeries(from:)
        )
    }

    final func search(query: String, page: Int, filters: FilterList) async throws -> SeriesPage {
        try await listing(
            url: searchURL(query: query, page: page, filters: filters),
            selector: searchSelector,
            nextPageSelector: searchNextPageSelector,
            extract: searchSeries(from:)
        )
    }

    /// Fetches details and folds them onto what is already known.
    ///
    /// The merge happens here rather than in the plugin, so that
    /// `source-detail-parsing`'s "enrich rather than replace" rule holds for every
    /// plugin without any plugin implementing it. A plugin that forgot it would
    /// still render a series — just one whose synopsis the refresh silently
    /// blanked, which is the kind of defect nothing reports.
    final func seriesDetails(for series: Series) async throws -> Series {
        let document = try await fetchDocument(series.url)
        let parsed = try parseDetails(document, known: series)
        guard !parsed.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SourceError.requiredFieldMissing(
                field: "title", source: name, url: series.url)
        }
        return series.enriched(with: parsed)
    }

    final func chapterList(for series: Series) async throws -> [Chapter] {
        let document = try await fetchDocument(series.url)
        let anchors = try document.select(chapterSelector).array()
        guard !anchors.isEmpty else {
            throw SourceError.requiredFieldMissing(
                field: "chapter list", source: name, url: series.url)
        }
        return try anchors.map {
            try chapter(from: $0, series: series)
        }
    }

    final func chapterContent(for chapter: Chapter) async throws -> ChapterContent {
        let document = try await fetchDocument(chapter.url)
        switch type {
        case .novel:
            return .text(html: try parseText(document))
        case .manhwa:
            return .pages(imageURLs: try parsePages(document))
        }
    }

    // MARK: - Shared listing path

    /// One listing page, for popular, latest, and search alike.
    ///
    /// A page that is reachable and parses but matches nothing is
    /// `SeriesPage.empty`, not a throw — `source-contract` is explicit that empty
    /// is not an error.
    private func listing(
        url: URL,
        selector: String,
        nextPageSelector: String?,
        extract: (Element) throws -> Series
    ) async throws -> SeriesPage {
        let document = try await fetchDocument(url)
        let entries = try document.select(selector).array().map { element in
            let series = try extract(element)
            guard !series.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SourceError.requiredFieldMissing(
                    field: "title", source: name, url: series.url)
            }
            return series
        }
        let hasMore = try nextPageSelector.map { try !document.select($0).isEmpty() } ?? false
        return SeriesPage(entries: entries, hasMore: hasMore)
    }

    /// The landing place for a template method a plugin failed to override.
    ///
    /// A plugin reaches this only if it was never exercised, and every plugin
    /// ships a fixture-driven test — so this fires in that test, at the bench,
    /// rather than in the reader's hands.
    private static func abstract(_ member: String, function: StaticString = #function) -> Never {
        preconditionFailure(
            "HTMLSource.\(member) is abstract and must be overridden by the plugin."
        )
    }
}

// MARK: - Extraction helpers

extension Element {
    /// The absolute URL in `attribute`, or `nil` if it is missing or unparseable.
    ///
    /// `abs:` resolves against the document's base URI, which is why
    /// `HTMLSource.parse` always sets one. A site that mixes relative and
    /// absolute hrefs — most of them — is handled without the plugin noticing.
    func absoluteURL(_ attribute: String = "href") throws -> URL? {
        let value = try attr("abs:\(attribute)")
        guard !value.isEmpty else { return nil }
        return URL(string: value)
    }

    /// This element's text, trimmed, or `nil` if it has none.
    ///
    /// `nil` rather than `""` so that the result drops straight into the merge,
    /// where absent and empty already mean the same thing.
    func trimmedText() throws -> String? {
        let value = try text().trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

extension Document {
    /// The first element matching `selector`, or `nil`.
    func first(_ selector: String) throws -> Element? {
        try select(selector).first()
    }
}
