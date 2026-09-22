import Foundation

/// What a source throws.
///
/// Sources throw rather than logging, catching, or returning a sentinel — see
/// `source-contract`. Every case carries the source name and the URL, because a
/// source that fails is diagnosed from the thrown message and a site that changed
/// its markup produces a lot of them at once.
///
/// Note what is *not* here: an "empty result" case. A reachable catalog page that
/// parses but holds no entries is `SeriesPage.empty`, not a failure.
public enum SourceError: Error, Equatable, Sendable {

    /// A field the series cannot be identified without could not be parsed.
    ///
    /// Distinct from a missing optional field, which degrades. A blank title is
    /// the defect `library-blank-title-repair` exists to repair; throwing here is
    /// how it stops being created.
    case requiredFieldMissing(field: String, source: String, url: URL)

    /// The site answered, with a status that is not a success.
    case httpStatus(code: Int, source: String, url: URL)

    /// The request did not complete within its timeout.
    ///
    /// Separated from `transport` because it is the one failure that is worth
    /// retrying unchanged — `isRetryable` is what the UI reads to decide whether
    /// to offer that.
    case timedOut(source: String, url: URL)

    /// The request failed before a response: no route, connection dropped, TLS.
    case transport(source: String, url: URL, underlying: String)

    /// The response body was not decodable as text.
    case undecodableResponse(source: String, url: URL)

    /// A plugin declared a `ContentType` whose content shape it never implemented.
    ///
    /// A programming error, surfaced the first time a chapter is opened. The
    /// alternative — a default returning empty text or no pages — is a chapter
    /// that renders blank and looks like a parse failure at the site's end.
    case contentShapeNotImplemented(source: String, type: ContentType, url: URL)

    /// Whether retrying the same request unchanged could plausibly succeed.
    ///
    /// A timeout and a transport failure can. A 404 and a missing title cannot —
    /// the site's answer or its markup would have to change first, and offering a
    /// retry for those trains the reader to tap a button that never works.
    public var isRetryable: Bool {
        switch self {
        case .timedOut, .transport:
            return true
        case .httpStatus(let code, _, _):
            // 5xx and 429 are the site's transient states. 4xx is the request
            // being wrong, which retrying does not fix.
            return code >= 500 || code == 429
        case .requiredFieldMissing, .undecodableResponse, .contentShapeNotImplemented:
            return false
        }
    }
}

extension SourceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .requiredFieldMissing(let field, let source, let url):
            return "\(source): could not parse required field '\(field)' at \(url)"
        case .httpStatus(let code, let source, let url):
            return "\(source): HTTP \(code) from \(url)"
        case .timedOut(let source, let url):
            return "\(source): request to \(url) timed out"
        case .transport(let source, let url, let underlying):
            return "\(source): request to \(url) failed — \(underlying)"
        case .undecodableResponse(let source, let url):
            return "\(source): response from \(url) was not decodable text"
        case .contentShapeNotImplemented(let source, let type, let url):
            let shape = type == .novel ? "chapter text" : "chapter pages"
            return "\(source): declares ContentType.\(type.rawValue) but never "
                + "implemented \(shape) for \(url)"
        }
    }
}
