import Foundation

/// The network seam downloads go through: a chapter's content, then each page's
/// bytes.
///
/// A protocol so the queue is tested without a network; the live one is the only
/// place a download touches one.
protocol DownloadTransport: Sendable {
    func content(for chapter: Chapter) async throws -> ChapterContent
    func pageData(from url: URL, chapter: Chapter) async throws -> Data
}

/// Content through the catalog — and so through the chapter's own source — and
/// page bytes through the shared `HTTPClient`, which keeps the per-host
/// concurrency bound in force for downloads too.
struct LiveDownloadTransport: DownloadTransport {
    let catalog: any CatalogRepository
    let http: HTTPClient

    func content(for chapter: Chapter) async throws -> ChapterContent {
        try await catalog.chapterContent(for: chapter)
    }

    func pageData(from url: URL, chapter: Chapter) async throws -> Data {
        // Image hosts commonly refuse a request with no referer; the chapter page
        // is the one a browser would have sent.
        try await http.data(
            from: url, source: "Downloads", headers: ["Referer": chapter.url.absoluteString])
    }
}

/// Why a download failed, beyond what the source or network threw.
enum DownloadError: Error, Equatable, LocalizedError {
    /// The source returned the other content shape for this chapter.
    case unexpectedContent(expected: ContentType)
    /// A page-based chapter listed no pages.
    case noPages

    var errorDescription: String? {
        switch self {
        case .unexpectedContent(let expected):
            "The source returned \(expected == .novel ? "images" : "text") for a "
                + "\(expected == .novel ? "novel" : "manhwa") chapter."
        case .noPages:
            "The chapter lists no pages."
        }
    }
}
