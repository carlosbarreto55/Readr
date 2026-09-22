import Foundation

/// The one path an outbound request takes.
///
/// Every source fetches through this type, so the guarantees
/// `source-request-performance` requires — a finite timeout, a bounded number of
/// concurrent requests per host, and a retryable error when time runs out — hold
/// for every plugin without a plugin opting in.
///
/// It returns text rather than a parsed document: parsing is SwiftSoup's job and
/// belongs to `HTMLSource`, which keeps this type usable by a future source that
/// reads JSON.
public final class HTTPClient: Sendable {
    private let session: URLSession
    private let limiter: HostConcurrencyLimiter
    private let timeout: TimeInterval
    private let userAgent: String

    /// - Parameters:
    ///   - session: The URL session used for transport.
    ///   - maxConcurrentRequestsPerHost: 4 by default. High enough that a manhwa
    ///     chapter's images load in parallel, low enough to stay unremarkable to
    ///     the site. `source-request-performance` fixes that a bound exists, not
    ///     its value.
    ///   - timeout: applies to each request individually.
    ///   - userAgent: Sent with every request unless a source overrides it.
    public init(
        session: URLSession = .shared,
        maxConcurrentRequestsPerHost: Int = 4,
        timeout: TimeInterval = 30,
        userAgent: String = "Readr/1.0 (personal)"
    ) {
        precondition(
            timeout.isFinite && timeout > 0,
            "Every source request needs a finite, positive timeout.")
        self.session = session
        self.limiter = HostConcurrencyLimiter(limit: maxConcurrentRequestsPerHost)
        self.timeout = timeout
        self.userAgent = userAgent
    }

    /// The body at `url`, as text.
    ///
    /// - Parameters:
    ///   - url: The remote document URL.
    ///   - source: The source's name, carried only so a thrown error can say which
    ///     site failed.
    ///   - headers: Source-specific request headers.
    /// - Returns: The decoded response body.
    /// - Throws: `SourceError`. Never a bare `URLError` — the layers above read
    ///   `isRetryable` to decide whether offering a retry is honest.
    public func text(
        from url: URL,
        source: String,
        headers: [String: String] = [:]
    ) async throws -> String {
        let data: Data
        let response: URLResponse
        (data, response) = try await fetch(url: url, source: source, headers: headers)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SourceError.httpStatus(code: http.statusCode, source: source, url: url)
        }
        guard let text = Self.decode(data, response: response) else {
            throw SourceError.undecodableResponse(source: source, url: url)
        }
        return text
    }

    /// The bytes at `url`, for a cover or a chapter page image.
    public func data(
        from url: URL,
        source: String,
        headers: [String: String] = [:]
    ) async throws -> Data {
        let (data, response) = try await fetch(url: url, source: source, headers: headers)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SourceError.httpStatus(code: http.statusCode, source: source, url: url)
        }
        return data
    }

    /// The high-water mark of concurrent requests against `host`.
    ///
    /// Exposed for the test that proves the bound holds. A limiter that is only
    /// usually right looks identical to a correct one until a site starts
    /// refusing requests, so the assertion has to be on the peak.
    public func peakConcurrency(for host: String) async -> Int {
        await limiter.peakConcurrency(for: host)
    }

    private func fetch(
        url: URL,
        source: String,
        headers: [String: String]
    ) async throws -> (Data, URLResponse) {
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: timeout)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        // Host rather than absolute URL: the bound protects the site, and every
        // path on it draws from the same budget.
        let host = url.host() ?? url.absoluteString
        let session = self.session
        let prepared = request

        return try await limiter.withPermit(host: host) {
            do {
                return try await session.data(for: prepared)
            } catch let error as URLError where error.code == .timedOut {
                throw SourceError.timedOut(source: source, url: url)
            } catch let error as URLError {
                throw SourceError.transport(
                    source: source, url: url, underlying: error.localizedDescription)
            }
        }
    }

    /// Decodes a response body, honoring the charset the site declared.
    ///
    /// Sites in this space are frequently not UTF-8 and are frequently wrong
    /// about it, so this tries what the response claims, then UTF-8, then
    /// Latin-1 — which decodes any byte sequence and so always terminates the
    /// chain. Returning mojibake beats throwing on a page that a reader could
    /// otherwise read.
    private static func decode(_ data: Data, response: URLResponse) -> String? {
        if let name = response.textEncodingName {
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
            if cfEncoding != kCFStringEncodingInvalidId {
                let encoding = String.Encoding(
                    rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
                if let text = String(data: data, encoding: encoding) {
                    return text
                }
            }
        }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
    }
}
